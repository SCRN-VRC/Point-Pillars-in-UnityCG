Shader "PointPillars/NMS"
{
    Properties
    {
        _IndexTex ("Sorted Index Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+13" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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
            Texture2D<float4> _IndexTex;
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

            float frag (v2f i) : SV_Target
            {
                clip(i.uv.z);
                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos2[21];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);

                //float col = _LayersTex[px];

                px -= renderPos.xy;
                uint2 idXY;
                uint width = _IndexTex_TexelSize.z;
                idXY.x = px.x % width;
                idXY.y = px.x / width;
                float2 myConfClass = _IndexTex[idXY].xz;

                if (myConfClass.x > 0.0)
                {
                    float3 myCenter;
                    myCenter.x = _LayersTex[layerPos2[20] + uint2(px.x, 0)];
                    myCenter.y = _LayersTex[layerPos2[20] + uint2(px.x, 1)];
                    myCenter.z = _LayersTex[layerPos2[20] + uint2(px.x, 2)];
                    float myRadius = min(_LayersTex[layerPos2[20] + uint2(px.x, 3)],
                        _LayersTex[layerPos2[20] + uint2(px.x, 4)]) * 0.5;

                    // if (px.x == 1)
                    // {
                    //     buffer[0] = float4(myCenter, myRadius);
                    // }

                    bool skip = false;
                    for (int i = px.x - 1; i >= 0; i--)
                    {
                        idXY.x = i % width;
                        idXY.y = i / width;
                        float2 otherConfClass = _IndexTex[idXY].xz;
                        // only same classes
                        if (otherConfClass.y != myConfClass.y) continue;

                        // simple sphere intersection test, i have a more detailed
                        // implementation of "rotation robust intersection over union"
                        // in my c++ code
                        float3 otherCenter;
                        otherCenter.x = _LayersTex[layerPos2[20] + int2(i, 0)];
                        otherCenter.y = _LayersTex[layerPos2[20] + int2(i, 1)];
                        otherCenter.z = _LayersTex[layerPos2[20] + int2(i, 2)];

                        float otherRadius = min(_LayersTex[layerPos2[20] + int2(i, 3)],
                            _LayersTex[layerPos2[20] + int2(i, 4)]) * 0.5;
                        float overlap = distance(myCenter, otherCenter) - (myRadius + otherRadius);

                        // something better and overlaps
                        if (otherConfClass.x > myConfClass.x && overlap < 0.0)
                        {
                            skip = true;
                            break;
                        }
                    }

                    // if (px.x == 6)
                    // {
                    //     buffer[0] = float4(myConfClass.y, skip, myCenter.xy);
                    // }

                    return skip ? -1.0 : px.x;
                }

                return -1.0;
            }
            ENDCG
        }
    }
}