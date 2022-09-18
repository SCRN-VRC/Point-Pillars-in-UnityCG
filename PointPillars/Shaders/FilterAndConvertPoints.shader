/*
    Filter out points beyond specified range, round floating point data 
    into ints for "pillars". Refer to the original PointPillars paper or 
    Github README
    https://arxiv.org/abs/1812.05784
*/

Shader "PointPillars/FilterAndConvertPoints"
{
    Properties
    {
        _InputTex ("Input Image", 2D) = "black" {}
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
            Texture2D<float4> _InputTex;
            float4 _InputTex_TexelSize;
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

                uint2 px = i.uv.xy * _InputTex_TexelSize.zw;
                float4 lidarData = _InputTex[px];

                bool skip = false;
                if (lidarData[0] <= coors_range[0] || lidarData[0] >= coors_range[3]) skip = true;
                if (lidarData[1] <= coors_range[1] || lidarData[1] >= coors_range[4]) skip = true;
                if (lidarData[2] <= coors_range[2] || lidarData[2] >= coors_range[5]) skip = true;

                float4 convertData = MAX_FLOAT;

                if (!skip)
                {
                    [unroll]
                    for (int i = 0; i < 3; i++)
                        convertData[i] = floor((lidarData[i] - coors_range[i]) / voxel_size[i]);
                    // save a reference to the orignal points
                    convertData.w = px.x + px.y * _InputTex_TexelSize.z;
                }

                return convertData;
            }
            ENDCG
        }
    }
}