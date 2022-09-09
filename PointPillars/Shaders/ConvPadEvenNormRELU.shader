Shader "PointPillars/ConvPadEvenNormRELU"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _WeightsTex ("Baked Weights", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _PrevCurLayerIDLoop ("Prev Layer, Current Layer, Layer Counter ID", Vector) = (0, 0, 0, 0)
        _LayerOffsets ("Prev Layer Split, Width, Height", Vector) = (0, 0, 0, 0)
        _CurOffsets ("Current Layer Split, Width, Height", Vector) = (0, 0, 0, 0)
        _WeightNormMeanVar ("Weight, Gamma, Beta, Mean/Variance", Vector) = (0, 0, 0, 0)
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+2" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        Blend Off
        Cull Front

        Pass
        {
            Lighting Off
            SeparateSpecular Off
            ZTest Off
            Fog { Mode Off }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "PointPillarsInclude.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            //RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float> _LayersTex;
            Texture2D<float> _WeightsTex;
            Texture2D<float> _ControllerTex;
            float4 _LayersTex_TexelSize;
            uint4 _WeightNormMeanVar;
            uint4 _PrevCurLayerIDLoop;
            uint4 _LayerOffsets;
            uint4 _CurOffsets;
            float _MaxDist;

            UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_INSTANCING_BUFFER_END(Props)

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.vertex = float4(v.uv * 2 - 1, 0, 1);
                #ifdef UNITY_UV_STARTS_AT_TOP
                v.uv.y = 1-v.uv.y;
                #endif
                o.uv.xy = UnityStereoTransformScreenSpaceTex(v.uv);
                o.uv.z = distance(_WorldSpaceCameraPos,
                   mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0)).xyz) > _MaxDist ? -1.0 : 1.0;
                o.uv.z = unity_OrthoParams.w ? o.uv.z : -1.0;
                return o;
            }

            float frag (v2f i) : SV_Target
            {
                clip(i.uv.z);
                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos2[_PrevCurLayerIDLoop.y];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);
                
                float col = _LayersTex[px];
                uint layerHash = _ControllerTex[txLayerHash];

                if (layerHash % primes[_PrevCurLayerIDLoop.z] == 0)
                {
                    px -= renderPos.xy;
                    uint l = px.x % _CurOffsets.y;
                    uint m = px.y % _CurOffsets.z;
                    uint k = px.x / _CurOffsets.y + (px.y / _CurOffsets.z) * _CurOffsets.x;

                    float s = 0.0f;
                    uint l0 = l, l1 = l0 + 1, l2 = l0 + 2;
                    uint m0 = m, m1 = m0 + 1, m2 = m0 + 2;

                    for (uint n = 0; n < _PrevCurLayerIDLoop.w; n++) {
                        s += dot(
                            float4(
                                padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l0, m0, n)),
                                padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l0, m1, n)),
                                padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l0, m2, n)),
                                padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l1, m0, n))
                            ),
                            float4(
                                getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 0, 0)),
                                getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 0, 1)),
                                getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 0, 2)),
                                getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 1, 0))
                            )
                        );
                        s += dot(
                            float4(
                                padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l1, m1, n)),
                                padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l1, m2, n)),
                                padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l2, m0, n)),
                                padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l2, m1, n))
                            ),
                            float4(
                                getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 1, 1)),
                                getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 1, 2)),
                                getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 2, 0)),
                                getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 2, 1))
                            )
                        );
                        s += padLayerEven(_LayersTex, _PrevCurLayerIDLoop.x, _LayerOffsets, _CurOffsets.yz, uint3(l2, m2, n)) *
                            getConst(_WeightsTex, _WeightNormMeanVar.x, uint4(k, n, 2, 2));
                    }

                    // if (l == 110 && m == 106 && k == 127 && _PrevCurLayerIDLoop.y == 6)
                    // {
                    //     buffer[0] = s;
                    // }

                    s = batchNorm(
                        s,
                        getConst(_WeightsTex, _WeightNormMeanVar.y, uint2(k, 0)),
                        getConst(_WeightsTex, _WeightNormMeanVar.z, uint2(k, 0)),
                        getMeanVar(_WeightsTex, _WeightNormMeanVar.w, k),
                        getMeanVar(_WeightsTex, _WeightNormMeanVar.w + 1, k));

                    s = relu(s);

                    // if (l == 109 && m == 107 && k == 127 && _PrevCurLayerIDLoop.y == 10)
                    // {
                    //     buffer[0] = s;
                    // }

                    return s;
                }
                return col;
            }
            ENDCG
        }
    }
}