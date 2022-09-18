/*
    Save the best confidence and best class prediction with
    a reference to the current pixel for later
*/

Shader "PointPillars/Reshape"
{
    Properties
    {
        _InputTex ("Input Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
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
            Texture2D<float> _InputTex;
            Texture2D<float> _LayersTex;
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

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint id = px.x + px.y * _LayersTex_TexelSize.z;

                // total # points to consider
                if (id < 321408)
                {
                    float4 data = 0.0;

                    /*
                        data.x = prediction confidence
                        data.y = id of prediction
                        data.z = prediction class: person, cyclist, car
                    */

                    data.x = reshape2to3(_InputTex, 10, uint4(3, 3, 248, 216), 3, id, 0);
                    data.y = id;
                    for (uint j = 1; j < 3; j++)
                    {
                        // 3 confidence scores for 3 classes
                        float predictConf = reshape2to3(_InputTex, 10, uint4(3, 3, 248, 216), 3, id, j);
                        // save the class with the best confidence
                        if (predictConf > data.x)
                        {
                            data.x = predictConf;
                            data.z = j;
                        }
                    }

                    return data;
                }

                return 0.0;
            }
            ENDCG
        }
    }
}