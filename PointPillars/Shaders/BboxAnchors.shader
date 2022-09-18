/*
    Get the precalcuated anchors for the pillars for each prediction
*/

Shader "PointPillars/BboxAnchors"
{
    Properties
    {
        _IndexTex ("Sorted Index Texture", 2D) = "black" {}
        _InputTex ("Input Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.2
    }
    SubShader
    {
        Tags { "Queue"="Overlay+12" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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
            Texture2D<float> _InputTex;
            Texture2D<float> _LayersTex;
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

            // mapping anchor 2d -> 3d array
            float anchor2to3(uint x, uint y)
            {
                //float*** anchorArray[3] = { l31, l32, l33 };
                uint3 input;
                input.x = x / 1296;
                input.y = (x / 6) % 216;
                input.z = (x % 2) + y * 2;
                //return anchorArray[(x / 2) % 3][i][j][k];
                return getLayer1(_InputTex, 13 + ((x / 2) % 3), uint4(7, 7, 248, 216), input);
            }

            float frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos2[19];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);

                //float col = _LayersTex[px];

                px -= renderPos.xy;
                uint2 idXY;
                uint width = _IndexTex_TexelSize.z;
                idXY.x = px.x % width;
                idXY.y = px.x / width;
                uint id = round(_IndexTex[idXY].y);
                float o = anchor2to3(id, px.y);

                return o;
            }
            ENDCG
        }
    }
}