Shader "PointPillars/PointsCenter"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _CoordsTex ("Grid Coords Texture", 2D) = "black" {}
        _CounterTex ("Counter Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+2" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        ZWrite Off
        ZTest Always
        Cull Front
        
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
            Texture2D<float4> _CoordsTex;
            Texture2D<float> _LayersTex;
            Texture2D<float> _ControllerTex;
            Texture2D<float> _CounterTex;
            float4 _CoordsTex_TexelSize;
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

            float gridSum(uint2 px, uint2 voxel, uint layer, uint dWidth, bool increment)
            {
                uint id = px.x + px.y * dWidth;
                float sum = 0.0;
                uint searchID = id;
                uint count = 0;

                while (searchID > 0 && count <= MAX_POINTS)
                {
                    searchID = increment ? searchID + 1 : searchID - 1;
                    count++;
                    uint2 searchPos;
                    searchPos.x = searchID % dWidth;
                    searchPos.y = searchID / dWidth;
                    if (any(uint2(_CoordsTex[searchPos].xy) != voxel)) break;
                    sum += getL1(_LayersTex, uint3(searchPos, layer));
                }
                return sum;
            }

            float frag (v2f i) : SV_Target
            {
                clip(i.uv.z);
                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos1[1];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);
                
                px -= renderPos.xy;
                uint dWidth = _CoordsTex_TexelSize.w;
                uint layer = px.x / dWidth;
                uint pxm = px.x % dWidth;

                float curVal = getL1(_LayersTex, uint3(pxm, px.y, layer));
                if (curVal == MAX_FLOAT) return MAX_FLOAT;
                
                uint2 px2 = uint2(pxm, px.y);
                uint2 curVoxel = _CoordsTex[px2].xy;

                float val = gridSum(px2, curVoxel, layer, dWidth, false) +
                    gridSum(px2, curVoxel, layer, dWidth, true) + curVal;

                float voxCount = _CounterTex[curVoxel];
                val = curVal - (val / voxCount);

                return val;
            }
            ENDCG
        }
    }
}