/*
    Uses _CameraDepthTexture to output world position per pixel
    to be used as Lidar input data
*/

Shader "PointPillars/DepthToObjPos"
{
    Properties
    {
        _MaxDist ("Max Distance", Float) = 0.2
    }
    SubShader
    {
        Tags { "Queue"="Overlay" "ForceNoShadowCasting"="True" }
        Cull Off

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
                float4 modelPos : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            //RWStructuredBuffer<float4> buffer : register(u1);

            float _MaxDist;

            UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_INSTANCING_BUFFER_END(Props)

            // d4rkpl4y3r's code for SPS-I compatibility
        #ifdef UNITY_STEREO_INSTANCING_ENABLED
            Texture2DArray<float> _CameraDepthTexture;
            Texture2DArray _ScreenTexture;
        #else
            Texture2D<float> _CameraDepthTexture;
            Texture2D _ScreenTexture;
        #endif

            SamplerState point_clamp_sampler;

            float SampleScreenDepth(float2 uv)
            {
            #ifdef UNITY_STEREO_INSTANCING_ENABLED
                return _CameraDepthTexture.SampleLevel(point_clamp_sampler, float3(uv, unity_StereoEyeIndex), 0);
            #else
                return _CameraDepthTexture.SampleLevel(point_clamp_sampler, uv, 0);
            #endif
            }

            bool DepthTextureExists()
            {
            #ifdef UNITY_STEREO_INSTANCING_ENABLED
                float3 dTexDim, sTexDim;
                _CameraDepthTexture.GetDimensions(dTexDim.x, dTexDim.y, dTexDim.z);
                _ScreenTexture.GetDimensions(sTexDim.x, sTexDim.y, sTexDim.z);
            #else
                float2 dTexDim, sTexDim;
                _CameraDepthTexture.GetDimensions(dTexDim.x, dTexDim.y);
                _ScreenTexture.GetDimensions(sTexDim.x, sTexDim.y);
            #endif
                return all(dTexDim == sTexDim);
            }

            float4x4 INVERSE_UNITY_MATRIX_VP;

            float3 calculateWorldSpace(float4 screenPos)
            {
                // Transform from adjusted screen pos back to world pos
                float4 worldPos = mul(INVERSE_UNITY_MATRIX_VP, screenPos);
                // Subtract camera position from vertex position in world
                // to get a ray pointing from the camera to this vertex.
                float3 worldDir = worldPos.xyz / worldPos.w - UNITY_MATRIX_I_V._14_24_34;
                // Calculate screen UV
                float2 screenUV = screenPos.xy / screenPos.w;
                screenUV.y *= _ProjectionParams.x;
                screenUV = screenUV * 0.5f + 0.5f;
                // Adjust screen UV for VR single pass stereo support
                screenUV = UnityStereoTransformScreenSpaceTex(screenUV);
                // Read depth, linearizing into worldspace units.
                float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(SampleScreenDepth(screenUV))) / screenPos.w;
                // Advance by depth along our view ray from the camera position.
                // This is the worldspace coordinate of the corresponding fragment
                // we retrieved from the depth buffer.
                return worldDir * depth;
            }

            // from http://answers.unity.com/answers/641391/view.html
            // creates inverse matrix of input
            float4x4 inverse(float4x4 input)
            {
                #define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
                float4x4 cofactors = float4x4(
                    minor(_22_23_24, _32_33_34, _42_43_44),
                    -minor(_21_23_24, _31_33_34, _41_43_44),
                    minor(_21_22_24, _31_32_34, _41_42_44),
                    -minor(_21_22_23, _31_32_33, _41_42_43),

                    -minor(_12_13_14, _32_33_34, _42_43_44),
                    minor(_11_13_14, _31_33_34, _41_43_44),
                    -minor(_11_12_14, _31_32_34, _41_42_44),
                    minor(_11_12_13, _31_32_33, _41_42_43),

                    minor(_12_13_14, _22_23_24, _42_43_44),
                    -minor(_11_13_14, _21_23_24, _41_43_44),
                    minor(_11_12_14, _21_22_24, _41_42_44),
                    -minor(_11_12_13, _21_22_23, _41_42_43),

                    -minor(_12_13_14, _22_23_24, _32_33_34),
                    minor(_11_13_14, _21_23_24, _31_33_34),
                    -minor(_11_12_14, _21_22_24, _31_32_34),
                    minor(_11_12_13, _21_22_23, _31_32_33)
                );
                #undef minor
                return transpose(cofactors) / determinant(input);
            }

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv.xy = v.uv;
                o.uv.z = distance(_WorldSpaceCameraPos,
                   mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0)).xyz) > _MaxDist ? -1.0 : 1.0;
                o.uv.z = unity_OrthoParams.w == 0 ? o.uv.z : -1.0;
                o.modelPos = o.vertex;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                // https://github.com/netri/Neitri-Unity-Shaders/blob/master/World%20Normal%20Nice%20Slow.shader
                // get the world position from the depth pass
                INVERSE_UNITY_MATRIX_VP = inverse(UNITY_MATRIX_VP);
                float4 screenPos = i.modelPos;
                float3 worldPos = calculateWorldSpace(screenPos) + UNITY_MATRIX_I_V._14_24_34;

                return float4(worldPos, 1.0);
            }
            ENDCG
        }
    }
}