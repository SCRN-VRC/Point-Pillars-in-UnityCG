/*
    Move the actual lidar data into the voxelized grid that can
    contain up to MAX_POINTS called "pillars"
*/

Shader "PointPillars/Pillars"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _InputTex ("Input Image", 2D) = "black" {}
        _OrigTex ("Original Points Data", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.2
    }
    SubShader
    {
        Tags { "Queue"="Overlay+2" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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
            Texture2D<float4> _OrigTex;
            Texture2D<float> _LayersTex;
            Texture2D<float> _ControllerTex;
            float4 _LayersTex_TexelSize;
            float4 _InputTex_TexelSize;
            float4 _OrigTex_TexelSize;
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

            float frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos1[0];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);

                float col = _LayersTex[px];
                uint layerHash = _ControllerTex[txLayerHash];

                if (layerHash % primes[0] == 0)
                {
                    const uint dWidth = _OrigTex_TexelSize.z;
                    px -= renderPos.xy;
                    uint layer = px.x / dWidth;
                    px.x = px.x % dWidth;

                    // use the reference ID that we saved b4
                    float lookupID = _InputTex[px].w;

                    if (lookupID < MAX_FLOAT)
                    {
                        uint2 IDPos;
                        IDPos.x = ((uint) lookupID) % dWidth;
                        IDPos.y = ((uint) lookupID) / dWidth;

                        // if (all(px == uint2(227, 83)) && layer == 0)
                        // {
                        //     buffer[0] = float4(IDPos, 0, 0);
                        // }

                        // as long as it's not invalid, save the data into 
                        // the "pillars"
                        return _OrigTex[IDPos][layer];
                    }
                    return MAX_FLOAT;
                }
                return col;
            }
            ENDCG
        }
    }
}