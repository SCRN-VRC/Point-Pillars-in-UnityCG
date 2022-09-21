Shader "PointPillars/FinalOut"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _IndexTex ("Sorted Index Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.2
    }
    SubShader
    {
        Tags { "Queue"="Overlay+14" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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
            Texture2D<float4> _IndexTex;
            Texture2D<float> _LayersTex;
            Texture2D<float> _ControllerTex;
            float4 _LayersTex_TexelSize;
            float4 _IndexTex_TexelSize;
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

            float limit_period(float val, float offset, float period)
            {
                return val - floor(val / period + offset) * period;
            }

            static const uint mapToUnity[9] =
            {
                0, 1, 3, 4, 2, 5, 7, 6, 8
            };

            float frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos2[23];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);

                float col = _LayersTex[px];
                uint layerHash = _ControllerTex[txLayerHash];

                if (layerHash % primes[32] == 0)
                {
                    px -= renderPos.xy;

                    int index = _LayersTex[layerPos2[22] + int2(px.x, 0)];
                    if (index < 0) return -1.0;

                    uint2 idXY;
                    uint width = _IndexTex_TexelSize.z;
                    idXY.x = index % width;
                    idXY.y = index / width;
                    float2 myConfClass = _IndexTex[idXY].xz;

                    float o = _LayersTex[layerPos2[20] + int2(index, mapToUnity[px.y] - 2)];

                    switch(px.y)
                    {
                        case 0: return myConfClass.x;
                        case 1: return myConfClass.y;
                        case 2:
                        case 3: o = -o; break;
                        case 8:
                        {
                            float dir = _LayersTex[layerPos2[18] + int2(index, 0)];
                            o = limit_period(o, 1.0, UNITY_PI);
                            o += (1.0 - dir) * UNITY_PI;
                            // Unity fix
                            o = UNITY_PI * 1.5 - o;
                            return o;
                        }
                    }

                    return o;
                }

                return col;
            }
            ENDCG
        }
    }
}