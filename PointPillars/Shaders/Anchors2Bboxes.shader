Shader "PointPillars/Anchors2Bboxes"
{
    Properties
    {
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+11" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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

            RWStructuredBuffer<float4> buffer : register(u1);
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

            float frag (v2f i) : SV_Target
            {
                clip(i.uv.z);
                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos2[20];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);

                //float col = _LayersTex[px];

                px -= renderPos.xy;

                float anchor3 = _LayersTex[layerPos2[19] + uint2(px.x, 3)];
                float anchor4 = _LayersTex[layerPos2[19] + uint2(px.x, 4)];
                float da = sqrt(pow(anchor3, 2) + pow(anchor4, 2));

                float delta2 = _LayersTex[layerPos2[17] + uint2(px.x, 2)];
                float anchor2 = _LayersTex[layerPos2[19] + uint2(px.x, 2)];
                float anchor5 = _LayersTex[layerPos2[19] + uint2(px.x, 5)];
                float z = delta2 * anchor5 + anchor2 + anchor5 * 0.5;
                
                float delta5 = _LayersTex[layerPos2[17] + uint2(px.x, 5)];
                float h = anchor5 * exp(delta5);

                z = z - h * 0.5;

                switch(px.y)
                {
                    case 0:
                    {
                        float delta0 = _LayersTex[layerPos2[17] + uint2(px.x, 0)];
                        float anchor0 = _LayersTex[layerPos2[19] + uint2(px.x, 0)];
                        if (px.x == 1) buffer[0] = float4(delta0, anchor0, 0, 0);
                        return delta0 * da + anchor0;
                    }
                    case 1:
                    {
                        float delta1 = _LayersTex[layerPos2[17] + uint2(px.x, 1)];
                        float anchor1 = _LayersTex[layerPos2[19] + uint2(px.x, 1)];
                        return delta1 * da + anchor1;
                    }
                    case 2:
                    {
                        return z;
                    }
                    case 3:
                    {
                        float delta3 = _LayersTex[layerPos2[17] + uint2(px.x, 3)];
                        return anchor3 * exp(delta3);
                    }
                    case 4:
                    {
                        float delta4 = _LayersTex[layerPos2[17] + uint2(px.x, 4)];
                        return anchor4 * exp(delta4);
                    }
                    case 5:
                    {
                        return h;
                    }
                    case 6:
                    {
                        float delta6 = _LayersTex[layerPos2[17] + uint2(px.x, 6)];
                        float anchor6 = _LayersTex[layerPos2[19] + uint2(px.x, 6)];
                        return delta6 + anchor6;
                    }
                }

                return 0.0;
            }
            ENDCG
        }
    }
}