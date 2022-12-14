/*
    Anchor position to convert world space of the lidar data
    into object space. Corresponding game object should be 
    1 unit high for best results.
*/

Shader "PointPillars/ObjToIntensity"
{
    Properties
    {
        _ObjPosTex ("Object Position Texture", 2D) = "black" {}
        _OutputTex ("Output Texture Size", 2D) = "black" {}
        _Reflectance ("Lidar Reflectance", Float) = 0.15
        _MaxDist ("Max Distance", Float) = 0.2
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
            ZTest Always
            Fog { Mode Off }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"

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
            Texture2D<float4> _ObjPosTex;
            Texture2D<float4> _OutputTex;
            float4 _ObjPosTex_TexelSize;
            float4 _OutputTex_TexelSize;
            float _Reflectance;
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

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _OutputTex_TexelSize.zw;
                uint id = px.x + px.y * _OutputTex_TexelSize.z;

                uint2 objPx;
                const uint width = _ObjPosTex_TexelSize.z;
                objPx.x = id % width;
                objPx.y = id / width;

                float3 pos1 = mul(unity_WorldToObject, _ObjPosTex[objPx]);
                
                // ignore points too close
                if (pos1.z < 0.0) return 1e6;

                // convert Unity coords into what the network's trained for
                pos1.xyz = float3(pos1.z, -pos1.x, pos1.y);

                // just return 0.15 for lidar reflectance
                return float4(pos1, _Reflectance);
            }
            ENDCG
        }
    }
}