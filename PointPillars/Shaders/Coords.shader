Shader "PointPillars/Coords"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _InputTex ("Input Texture", 2D) = "black" {}
        _CounterTex ("Counter Texture", 2D) = "black" {}
        _ActiveTexelMap ("Active Texel Map", 2D) = "black" {}
        //_ActiveTexelMap2 ("Active Texel Map 2", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+1" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
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
            Texture2D<float> _ControllerTex;
            Texture2D<float> _ActiveTexelMap;
            //Texture2D<float> _ActiveTexelMap2;
            Texture2D<float> _CounterTex;
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
                clip(i.uv.z);
                UNITY_SETUP_INSTANCE_ID(i);

                uint2 px = i.uv.xy * _InputTex_TexelSize.zw;
                float loopCount = _ControllerTex[txSortInputLoop];
                float totalCount = round((1 << 18) * _ActiveTexelMap.Load(int3(0, 0, 9)));
                //float tc2 = round((1 << 18) * _ActiveTexelMap2.Load(int3(0, 0, 9)));

                float curID = px.x + px.y * _InputTex_TexelSize.z;

                if (curID < totalCount)
                {
                    const uint dataWidth = _InputTex_TexelSize.z;
                    uint2 voxel = floor(_InputTex[px].xy);
                    float voxelCount = _CounterTex[voxel];

                    if (voxelCount > 32)
                    {
                        float searchID = curID;
                        float indexCount = 0;
                        while (searchID > 0 && indexCount <= voxelCount)
                        {
                            searchID--;
                            indexCount++;
                            uint2 searchPos;
                            searchPos.x = searchID % dataWidth;
                            searchPos.y = searchID / dataWidth;
                            if (any(uint2(_InputTex[searchPos].xy) != voxel)) break;
                        }
                        return indexCount > 32.0 ? MAX_FLOAT : _InputTex[px];
                    }
                    else return _InputTex[px];
                }
                return MAX_FLOAT;
            }
            ENDCG
        }
    }
}