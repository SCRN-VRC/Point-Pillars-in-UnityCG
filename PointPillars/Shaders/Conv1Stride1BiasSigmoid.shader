/*
    Concatenate the three output layers of the repurposed image classifer together
    to predict a confidence value for each class
*/

Shader "PointPillars/Conv1Stride1BiasSigmoid"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _WeightsTex ("Baked Weights", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
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
                uint4 renderPos = layerPos1[10];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);
                
                float col = _LayersTex[px];
                uint layerHash = _ControllerTex[txLayerHash];

                if (layerHash % primes[21] == 0)
                {
                    px -= renderPos.xy;
                    uint l = px.x % 248;
                    uint m = px.y % 216;
                    uint k = px.x / 248 + (px.y / 216) * 3;

                    float s = 0.0;
                    uint n = 0;
                    // kernel
                    for (; n < 128; n += 4) {
                        //s += pl0[n][l][m] * w0[k][n][0][0];
                        s += dot(
                            float4(
                                getLayer1(_LayersTex, 7, uint4(8, 8, 248, 216), uint3(l, m, n)),
                                getLayer1(_LayersTex, 7, uint4(8, 8, 248, 216), uint3(l, m, n + 1)),
                                getLayer1(_LayersTex, 7, uint4(8, 8, 248, 216), uint3(l, m, n + 2)),
                                getLayer1(_LayersTex, 7, uint4(8, 8, 248, 216), uint3(l, m, n + 3))
                            ),
                            float4(
                                getConst(_WeightsTex, 60, uint2(n, k)),
                                getConst(_WeightsTex, 60, uint2(n + 1, k)),
                                getConst(_WeightsTex, 60, uint2(n + 2, k)),
                                getConst(_WeightsTex, 60, uint2(n + 3, k))
                            )
                        );
                    }
                    for (n = 0; n < 128; n += 4) {
                        //s += pl1[n][l][m] * w0[k][n + 128][0][0];
                        s += dot(
                            float4(
                                getLayer1(_LayersTex, 8, uint4(8, 8, 248, 216), uint3(l, m, n)),
                                getLayer1(_LayersTex, 8, uint4(8, 8, 248, 216), uint3(l, m, n + 1)),
                                getLayer1(_LayersTex, 8, uint4(8, 8, 248, 216), uint3(l, m, n + 2)),
                                getLayer1(_LayersTex, 8, uint4(8, 8, 248, 216), uint3(l, m, n + 3))
                            ),
                            float4(
                                getConst(_WeightsTex, 60, uint2(n + 128, k)),
                                getConst(_WeightsTex, 60, uint2(n + 129, k)),
                                getConst(_WeightsTex, 60, uint2(n + 130, k)),
                                getConst(_WeightsTex, 60, uint2(n + 131, k))
                            )
                        );
                    }
                    for (n = 0; n < 128; n += 4) {
                        //s += pl2[n][l][m] * w0[k][n + 256][0][0];
                        s += dot(
                            float4(
                                getLayer1(_LayersTex, 9, uint4(8, 8, 248, 216), uint3(l, m, n)),
                                getLayer1(_LayersTex, 9, uint4(8, 8, 248, 216), uint3(l, m, n + 1)),
                                getLayer1(_LayersTex, 9, uint4(8, 8, 248, 216), uint3(l, m, n + 2)),
                                getLayer1(_LayersTex, 9, uint4(8, 8, 248, 216), uint3(l, m, n + 3))
                            ),
                            float4(
                                getConst(_WeightsTex, 60, uint2(n + 256, k)),
                                getConst(_WeightsTex, 60, uint2(n + 257, k)),
                                getConst(_WeightsTex, 60, uint2(n + 258, k)),
                                getConst(_WeightsTex, 60, uint2(n + 259, k))
                            )
                        );
                    }

                    // bias
                    s += getConst(_WeightsTex, 61, uint2(k, 0));
                    s = sigmoid(s);

                    // if (k == 6 && l == 116 && m == 24) buffer[0][0] = s;
                    // if (k == 7 && l == 116 && m == 24) buffer[0][1] = s;
                    // if (k == 8 && l == 116 && m == 24) buffer[0][2] = s;

                    return s;
                }
                return col;
            }
            ENDCG
        }
    }
}