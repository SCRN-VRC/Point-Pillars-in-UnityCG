Shader "PointPillars/CompactOutput"
{
    Properties
    {
        _DataTex("Sparse Texture", 2D) = "black" {}
        _ActiveTexelMap("Active Texel Map", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        [Toggle(Z_ORDER_CURVE)] _ZOrderCurve("Z Order Curve", Int) = 0
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+1" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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
            float4 _LayersTex_TexelSize;
            float _MaxDist;

            Texture2D _DataTex;
            Texture2D<float> _ActiveTexelMap;
            float4 _ActiveTexelMap_TexelSize;
            bool _ZOrderCurve;

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


            #define WIDTH ((uint)_ActiveTexelMap_TexelSize.z)
            #define HEIGHT ((uint)_ActiveTexelMap_TexelSize.w)

            // adapted from: https://lemire.me/blog/2018/01/08/how-fast-can-you-bit-interleave-32-bit-integers/
            uint InterleaveWithZero(uint word)
            {
                word = (word ^ (word << 8)) & 0x00ff00ff;
                word = (word ^ (word << 4)) & 0x0f0f0f0f;
                word = (word ^ (word << 2)) & 0x33333333;
                word = (word ^ (word << 1)) & 0x55555555;
                return word;
            }

            // adapted from: https://stackoverflow.com/questions/3137266/how-to-de-interleave-bits-unmortonizing
            uint DeinterleaveWithZero(uint word)
            {
                word &= 0x55555555;
                word = (word | (word >> 1)) & 0x33333333;
                word = (word | (word >> 2)) & 0x0f0f0f0f;
                word = (word | (word >> 4)) & 0x00ff00ff;
                word = (word | (word >> 8)) & 0x0000ffff;
                return word;
            }

            uint2 IndexToUV(uint index)
            {
                #ifdef Z_ORDER_CURVE
                return uint2(DeinterleaveWithZero(index), DeinterleaveWithZero(index >> 1));
                #else
                return uint2(index % HEIGHT, index / HEIGHT);
                #endif
            }

            uint UVToIndex(uint2 uv)
            {
                #ifdef Z_ORDER_CURVE
                return InterleaveWithZero(uv.x) | (InterleaveWithZero(uv.y) << 1);
                #else
                return uv.x + uv.y * WIDTH;
                #endif
            }

            float CountActiveTexels(int3 uv, int2 offset)
            {
                return (float)(1 << (uv.z + uv.z)) * _ActiveTexelMap.Load(uv, offset);
            }

            float CountActiveTexels(int3 uv)
            {
                return CountActiveTexels(uv, int2(0, 0));
            }

            int2 ActiveTexelIndexToUV(float index)
            {
                float maxLod = round(log2(HEIGHT));
                int3 uv = int3(0, 0, maxLod);

                if (index >= CountActiveTexels(uv))
                    return -1;
                float activeTexelSumInPreviousLods = 0;
                while (uv.z >= 1)
                {
                    uv += int3(uv.xy, -1);
                    float count00 = CountActiveTexels(uv);
                    float count01 = CountActiveTexels(uv, int2(1, 0));
                    float count10 = CountActiveTexels(uv, int2(0, 1));

                    bool in00 = index < (activeTexelSumInPreviousLods + count00);
                    bool in01 = index < (activeTexelSumInPreviousLods + count00 + count01);
                    bool in10 = index < (activeTexelSumInPreviousLods + count00 + count01 + count10);
                    if (in00)
                    {
                        uv.xy += int2(0, 0);
                    }
                    else if (in01)
                    {
                        uv.xy += int2(1, 0);
                        activeTexelSumInPreviousLods += count00;
                    }
                    else if (in10)
                    {
                        uv.xy += int2(0, 1);
                        activeTexelSumInPreviousLods += count00 + count01;
                    }
                    else
                    {
                        uv.xy += int2(1, 1);
                        activeTexelSumInPreviousLods += count00 + count01 + count10;
                    }
                }

                return uv.xy;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;

                int2 uv = ActiveTexelIndexToUV(px.x + px.y * _LayersTex_TexelSize.z);
                if (uv.x == -1)
                {
                    return 0;
                }
                return _DataTex[uv];

            }
            ENDCG
        }
    }
}