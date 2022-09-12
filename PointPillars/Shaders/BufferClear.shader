Shader "PointPillars/BufferClear"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _MainTex ("Buffer", 2D) = "black" {}
        _ClearArea ("Area to Clear", Int) = 0
        _ClearIndex ("Layer Index to Clear", Int) = 30
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

            Texture2D<float4> _MainTex;
            Texture2D<float> _ControllerTex;
            float4 _MainTex_TexelSize;
            uint _ClearArea;
            uint _ClearIndex;
            float _MaxDist;

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
                o.uv.z = (distance(_WorldSpaceCameraPos,
                    mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz) > _MaxDist) ?
                    -1 : 1;
                o.uv.z = unity_OrthoParams.w ? o.uv.z : -1;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.uv.z);

                uint2 px = i.uv.xy * _MainTex_TexelSize.zw;
                uint4 renderPos = layerPos2[_ClearArea];
                bool renderArea = insideArea(renderPos, px);

                uint layerHash = _ControllerTex[txLayerHash];
                if (renderArea && (layerHash % primes[_ClearIndex] == 0)) return 0;

                float4 col = _MainTex.Load(int3(i.uv.xy * _MainTex_TexelSize.zw, 0));
                return col;
            }
            ENDCG
        }
    }
}