/*
    Reshape the image classifier to be processed later for the three main ouputs:
    class, confidence, bounding box location, bounding box scale, and rotation
*/

Shader "PointPillars/ConvTranspose1Stride1"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _WeightsTex ("Baked Weights", 2D) = "black" {}
        _InputTex ("Input Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.2
    }
    SubShader
    {
        Tags { "Queue"="Overlay+6" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        Blend Off
        Cull Front

        Pass
        {
            Lighting Off
            SeparateSpecular Off
            ZTest Always
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
            Texture2D<float> _InputTex;
            Texture2D<float> _WeightsTex;
            Texture2D<float> _ControllerTex;
            float4 _LayersTex_TexelSize;
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
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos1[7];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);
                
                float col = _LayersTex[px];
                uint layerHash = _ControllerTex[txLayerHash];

                if (layerHash % primes[20] == 0)
                {
                    px -= renderPos.xy;
                    uint l = px.x % 248;
                    uint m = px.y % 216;
                    uint k = px.x / 248 + (px.y / 216) * 8;

                    float s = 0.0f;
                    for (uint n = 0; n < 64; n += 4) {
                        s += dot(
                            float4(
                                getLayer2(_InputTex, 4, uint4(8, 8, 248, 216), uint3(l, m, n)),
                                getLayer2(_InputTex, 4, uint4(8, 8, 248, 216), uint3(l, m, n + 1)),
                                getLayer2(_InputTex, 4, uint4(8, 8, 248, 216), uint3(l, m, n + 2)),
                                getLayer2(_InputTex, 4, uint4(8, 8, 248, 216), uint3(l, m, n + 3))
                            ),
                            float4(
                                getConst(_WeightsTex, 51, uint2(k, n)),
                                getConst(_WeightsTex, 51, uint2(k, n + 1)),
                                getConst(_WeightsTex, 51, uint2(k, n + 2)),
                                getConst(_WeightsTex, 51, uint2(k, n + 3))
                            )
                        );
                    }

                    s = batchNorm(
                        s,
                        getConst(_WeightsTex, 52, uint2(k, 0)),
                        getConst(_WeightsTex, 53, uint2(k, 0)),
                        getMeanVar(_WeightsTex, 34, k),
                        getMeanVar(_WeightsTex, 35, k));

                    s = relu(s);

                    // if (k == 0 && l == 116 && m == 24) buffer[0][0] = s;
                    // if (k == 64 && l == 116 && m == 24) buffer[0][1] = s;
                    // if (k == 127 && l == 116 && m == 24) buffer[0][2] = s;

                    return s;
                }
                return col;
            }
            ENDCG
        }
    }
}