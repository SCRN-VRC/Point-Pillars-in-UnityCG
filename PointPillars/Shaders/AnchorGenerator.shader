Shader "PointPillars/AnchorGenerator"
{
    Properties
    {
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _LayerAreaOffsets ("Current Layer Area, Split, Weights", Vector) = (0, 0, 0, 0)
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+8" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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
            Texture2D<float> _LayersTex;
            float4 _LayersTex_TexelSize;
            uint4 _LayerAreaOffsets;
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
                clip(i.uv.z);
                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos1[_LayerAreaOffsets.x];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);
                
                float col = _LayersTex[px];

                if (_Time.y < 0.1)
                {
                    px -= renderPos.xy;
                    uint l = px.x % 248;
                    uint m = px.y % 216;
                    uint k = px.x / 248 + (px.y / 216) * _LayerAreaOffsets.y;

                    int x = _LayerAreaOffsets.z;

                    const float step_x = (getAnchorRange(x, 3) - getAnchorRange(x, 0)) / 216.0;
                    const float step_y = (getAnchorRange(x, 4) - getAnchorRange(x, 1)) / 248.0;

                    const float shift_x = step_x / 2.0f;
                    const float shift_y = step_y / 2.0f;

                    switch(k)
                    {
                        case 0: 
                        case 1: return getAnchorRange(x, 0) + step_x * l + shift_x;
                        case 2:
                        case 3: return getAnchorRange(x, 1) + step_y * k + shift_y;
                        case 4:
                        case 5: return getAnchorRange(x, 2);
                        case 6:
                        case 7: return getAnchorSize(x, 0);
                        case 8:
                        case 9: return getAnchorSize(x, 1);
                        case 10:
                        case 11: return getAnchorSize(x, 2);
                        case 12: return anchor_rotations[0];
                        case 13: return anchor_rotations[1];
                    }

                    return 0.0;
                }
                // else{
                //     px -= renderPos.xy;
                //     uint l = px.x % 248;
                //     uint m = px.y % 216;
                //     uint k = px.x / 248 + (px.y / 216) * _LayerAreaOffsets.y;

                //     int x = _LayerAreaOffsets.z;

                //     if (l == 167 && m == 99 && k == 10)
                //     {
                //         if (x == 0) buffer[0][0] = col;
                //         if (x == 1) buffer[0][1] = col;
                //         if (x == 2) buffer[0][2] = col;
                //     }
                // }
                return col;
            }
            ENDCG
        }
    }
}