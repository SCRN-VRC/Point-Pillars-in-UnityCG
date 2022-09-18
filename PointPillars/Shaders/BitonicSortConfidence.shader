/*
    Sorts the compacted 32x32 confidence predictions.
*/

Shader "PointPillars/BitonicSortConfidence"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _IndexOffset ("Index Offset", Int) = 0
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
            Texture2D<float> _ControllerTex;
            Texture2D<float4> _LayersTex;
            float4 _LayersTex_TexelSize;
            uint _IndexOffset;
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

                uint loopCount = _ControllerTex[txSortConfLoop];
                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;

                uint flip = flipArray[loopCount * 13 + _IndexOffset];
                uint disperse = disperseArray[loopCount * 13 + _IndexOffset];

                if (loopCount >= MAX_CONF_LOOP)
                {
                    return _LayersTex[px];
                }
                else
                {
                    const uint WIDTH = _LayersTex_TexelSize.z;
                    uint i = px.x + px.y * WIDTH;
                    uint l = i ^ disperse;
                    uint2 tg;
                    tg.x = l % WIDTH;
                    tg.y = l / WIDTH;

                    float cdata = l > i ?
                        _LayersTex[px].x : _LayersTex[tg].x;
                    float tdata = l > i ?
                        _LayersTex[tg].x : _LayersTex[px].x;

                    if (
                        (((i & flip) == 0) && (cdata < tdata)) ||
                        (((i & flip) != 0) && (cdata > tdata))
                    )
                    {
                        return _LayersTex[tg];
                    }

                    return _LayersTex[px];
                }
            }
            ENDCG
        }
    }
}