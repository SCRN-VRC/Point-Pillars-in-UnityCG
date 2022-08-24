Shader "PointPillars/BitonicController"
{
    Properties
    {
        [Toggle] _Start ("Start", Float) = 0
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+1" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        ZWrite Off
        ZTest Always
        Cull Front
        
        Pass
        {
            Lighting Off
            SeparateSpecular Off
            Fog { Mode Off }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "Test.cginc"

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

            RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float> _LayersTex;
            float4 _LayersTex_TexelSize;
            float _MaxDist;
            bool _Start;

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

            #define STOP_STATE 0
            #define INIT_STATE 1
            #define FLIP_STATE 2
            #define DISPERSE_STATE 3

            float frag (v2f i) : SV_Target
            {
                clip(i.uv.z);

                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint flip = _LayersTex[uint2(0, 0)];
                uint disperse = _LayersTex[uint2(1, 0)];
                uint state = _LayersTex[uint2(2, 0)];

                state = _Time.y < 1 ? INIT_STATE : state;

                if (state == INIT_STATE)
                {
                    flip = 2;
                    disperse = 1;
                    state = DISPERSE_STATE;
                }
                else if (state == FLIP_STATE)
                {
                    flip = flip << 1;
                    disperse = flip >> 1;
                    state = flip > 262144 ? STOP_STATE : DISPERSE_STATE;
                    buffer[0][0]++;
                }
                else if (state == DISPERSE_STATE)
                {
                    state = disperse == 1 ? FLIP_STATE : state;
                    disperse = disperse >> 1;
                    buffer[0][0]++;
                }
                else if (state == STOP_STATE)
                {
                    state = _Start ? INIT_STATE : state;
                    buffer[0][1] = max(buffer[0][1], buffer[0][0]);
                    buffer[0][0] = 0;
                }
                else state = INIT_STATE;

                //buffer[0] = float4(state, flip, disperse, 0);

                if (all(px == uint2(0, 0))) return flip;
                if (all(px == uint2(1, 0))) return disperse;
                if (all(px == uint2(2, 0))) return state;
                return 0;
            }
            ENDCG
        }
    }
}