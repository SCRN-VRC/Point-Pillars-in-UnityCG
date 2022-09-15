Shader "PointPillars/ObjToIntensity"
{
    Properties
    {
        _ObjPosTex ("Object Position Texture", 2D) = "black" {}
        //_CameraOffset ("Camera Position Offset", Vector) = (0, 0, 0, 0)
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
            float4 _ObjPosTex_TexelSize;
            //float3 _CameraOffset;
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

            /*
                Tiny neural net to badly guesstimate the lidar intensity value from the 
                velodyne data given the distance and dot(cam dir, normal dir)
            */

            static const float2 l1w[4] = 
            {
                -0.7591883540153503, 0.3026984930038452,
                -0.3571877777576447, -0.1460973918437958,
                0.4043989479541779, -0.4192669987678528,
                -0.0404608212411404, -0.5110290646553040
            };

            static const float4 l1b = float4(-0.2132419049739838, -0.4368999898433685,
                                            0.4899159073829651, -0.4428287446498871);

            static const float4 l2w[4] =
            {
                0.4191814064979553,  0.0238442774862051, -0.5685261487960815, 0.0418070554733276,
                0.7314946651458740,  0.5241728425025940, -0.4206412136554718, -0.1350801885128021,
                -0.3824900090694427,  0.0109206773340702,  0.5811904668807983, 0.1730981618165970,
                0.2877964377403259,  0.6315559148788452,  0.1994829177856445, -0.1914826035499573
            };

            static const float4 l2b = float4(-0.3124515712261200, -0.5175706744194031,
                                            -0.1539248079061508, 0.3105266392230988);

            static const float4 l3w = float4(0.7584130167961121,  0.5915060043334961,
                                            -0.3376944065093994, 0.2077171504497528);

            static const float l3b = -0.6104651689529419;

            float4 softplus(float4 x)
            {
                return log(1.0 + exp(x));
            }

            float4 mish(float4 x)
            {
                return x * tanh(softplus(x));
            }

            float sigmoid(float x)
            {
                return 1.0f / (1.0 + exp(-x));
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _ObjPosTex_TexelSize.zw;
                float3 pos1 = mul(unity_WorldToObject, _ObjPosTex[px]);
                float3 pos2 = mul(unity_WorldToObject, _ObjPosTex[px + uint2(0, 1)]);
                float3 pos3 = mul(unity_WorldToObject, _ObjPosTex[px + uint2(1, 0)]);
                float3 norm = normalize(cross(pos2 - pos1, pos3 - pos1));

                if (pos1.z < 0.0) return 1e6;

                float2 input = float2(length(pos1) / 80.0, dot(normalize(pos1), norm));

                float4 o1;
                o1.x = dot(input, l1w[0]);
                o1.y = dot(input, l1w[1]);
                o1.z = dot(input, l1w[2]);
                o1.w = dot(input, l1w[3]);
                o1 = mish(o1 + l1b);

                float4 o2;
                o2.x = dot(o1, l2w[0]);
                o2.y = dot(o1, l2w[1]);
                o2.z = dot(o1, l2w[2]);
                o2.w = dot(o1, l2w[3]);
                o2 = mish(o2 + l2b);

                float o3 = dot(o2, l3w);
                o3 = sigmoid(o3 + l3b);

                // convert Unity coords into what the network's trained for
                //pos1 += _CameraOffset;
                pos1.xyz = pos1.zxy;
                return float4(pos1, o3);
            }
            ENDCG
        }
    }
}