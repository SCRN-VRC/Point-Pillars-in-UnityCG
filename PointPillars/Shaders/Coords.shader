/*
    Filter the points again, only MAX_POINTS allowed per pillar,
    default implementation is 32, removes extra points if the 
    maximum is exceeded.
*/

Shader "PointPillars/Coords"
{
    Properties
    {
        //_ControllerTex ("Controller Texture", 2D) = "black" {}
        _InputTex ("Input Texture", 2D) = "black" {}
        _CounterTex ("Counter Texture", 2D) = "black" {}
        _ActiveTexelMap ("Active Texel Map", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.2
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
            //Texture2D<float> _ControllerTex;
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
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _InputTex_TexelSize.zw;
                float totalCount = round((1 << 18) * _ActiveTexelMap.Load(int3(0, 0, 9)));
                float curID = px.x + px.y * _InputTex_TexelSize.z;

                // if the current point ID in the group is less than
                // the total group count
                if (curID < totalCount)
                {
                    const uint dataWidth = _InputTex_TexelSize.z;
                    uint2 voxel = _InputTex[px].xy;
                    float voxelCount = _CounterTex[voxel];

                    // if the total group count is above MAX_POINTS
                    if (voxelCount > MAX_POINTS)
                    {
                        uint searchID = curID;
                        float indexCount = 0;
                        // find if current point is above MAX_POINTS
                        while (searchID > 0 && indexCount <= voxelCount)
                        {
                            searchID--;
                            indexCount++;
                            uint2 searchPos;
                            searchPos.x = searchID % dataWidth;
                            searchPos.y = searchID / dataWidth;
                            if (any(uint2(_InputTex[searchPos].xy) != voxel)) break;
                        }
                        return indexCount > MAX_POINTS ? MAX_FLOAT : _InputTex[px];
                    }
                    else return _InputTex[px];
                }
                return MAX_FLOAT;
            }
            ENDCG
        }
    }
}