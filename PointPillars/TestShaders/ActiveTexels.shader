Shader "PointPillars/TestInput"
{
    Properties
    {
        _WeightsTex ("Baked Weights", 2D) = "black" {}
        _WeightBiasLoopID ("Weight, Bias, Loop Max, CurID", Vector) = (0, 0, 0, 0)
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
            float4 _WeightsTex_TexelSize;
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

            static const float coors_range[6] =
                { 0.0f, -39.68f, -3.0f, 69.12f, 39.68f, 1.0f };

            float frag (v2f i) : SV_Target
            {
                clip(i.uv.z);

                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _WeightsTex_TexelSize.zw;
                float4 col = _WeightsTex[px];

                bool skip = false;
                if (col[0] <= coors_range[0] || col[0] >= coors_range[3]) skip = true;
                if (col[1] <= coors_range[1] || col[1] >= coors_range[4]) skip = true;
                if (col[2] <= coors_range[2] || col[2] >= coors_range[5]) skip = true;

                return skip ? 0.0 : 1.0;
            }
            ENDCG
        }
    }
}