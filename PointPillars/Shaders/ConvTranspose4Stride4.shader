﻿Shader "PointPillars/ConvTranspose4Stride4"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _WeightsTex ("Baked Weights", 2D) = "black" {}
        _InputTex ("Input Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+7" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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
                clip(i.uv.z);
                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos1[9];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);
                
                float col = _LayersTex[px];
                uint layerHash = _ControllerTex[txLayerHash];

                if (layerHash % primes[21] == 0)
                {
                    px -= renderPos.xy;
                    uint l = px.x % 248;
                    uint m = px.y % 216;
                    uint k = px.x / 248 + (px.y / 216) * 8;

                    uint l0 = l / 4, m0 = m / 4;
                    uint x = l % 4, y = m % 4;

                    float s = 0.0f;
                    for (uint n = 0; n < 256; n += 4) {
                        s += dot(
                            float4(
                                getLayer2(_InputTex, 16, uint4(16, 16, 62, 54), uint3(l0, m0, n)),
                                getLayer2(_InputTex, 16, uint4(16, 16, 62, 54), uint3(l0, m0, n + 1)),
                                getLayer2(_InputTex, 16, uint4(16, 16, 62, 54), uint3(l0, m0, n + 2)),
                                getLayer2(_InputTex, 16, uint4(16, 16, 62, 54), uint3(l0, m0, n + 3))
                            ),
                            float4(
                                getConst4x4(_WeightsTex, 57, uint4(n, k, x, y)),
                                getConst4x4(_WeightsTex, 57, uint4(n + 1, k, x, y)),
                                getConst4x4(_WeightsTex, 57, uint4(n + 2, k, x, y)),
                                getConst4x4(_WeightsTex, 57, uint4(n + 3, k, x, y))
                            )
                        );
                    }

                    s = batchNorm(
                        s,
                        getConst(_WeightsTex, 58, uint2(k, 0)),
                        getConst(_WeightsTex, 59, uint2(k, 0)),
                        getMeanVar(_WeightsTex, 38, k),
                        getMeanVar(_WeightsTex, 39, k));

                    s = relu(s);

                    // if (l == 133 && m == 191 && k == 89)
                    // {
                    //     buffer[0] = s * 100;
                    // }

                    return s;
                }
                return col;
            }
            ENDCG
        }
    }
}