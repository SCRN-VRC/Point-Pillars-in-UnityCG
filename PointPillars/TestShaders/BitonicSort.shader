Shader "PointPillars/BitonicSort"
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

            //RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float4> _WeightsTex;
            Texture2D<float> _ControllerTex;
            Texture2D<float4> _LayersTex;
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
            
            uint pcg_hash(uint seed)
            {
                uint state = seed * 747796405u + 2891336453u;
                uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
                return (word >> 22u) ^ word;
            }

            #define STOP_STATE 0
            #define INIT_STATE 1
            #define FLIP_STATE 2
            #define DISPERSE_STATE 3

            float4 frag (v2f i) : SV_Target
            {
                clip(i.uv.z);

                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint flip = _ControllerTex[uint2(0, 0)];
                uint disperse = _ControllerTex[uint2(1, 0)];
                uint state = _ControllerTex[uint2(2, 0)];

                if (state == INIT_STATE)
                {
                    return _WeightsTex[px];
                }
                else if (state == STOP_STATE)
                {
                    return _LayersTex[px];
                }
                else
                {
                    const uint WIDTH = _LayersTex_TexelSize.z;
                    uint i = px.x + px.y * WIDTH;
                    uint l = i ^ disperse;
                    uint2 tg;
                    tg.x = l % WIDTH;
                    tg.y = l / WIDTH;

                    float cdata = l > i ? _LayersTex[px].x : _LayersTex[tg].x;
                    float tdata = l > i ? _LayersTex[tg].x : _LayersTex[px].x;

                    if (
                        (((i & flip) == 0) && (cdata < tdata)) ||
                        (((i & flip) != 0) && (cdata > tdata))
                    )
                    {
                        return _LayersTex[tg];
                    }

                    return _LayersTex[px];
                }
            }
            ENDCG
        }
    }
}