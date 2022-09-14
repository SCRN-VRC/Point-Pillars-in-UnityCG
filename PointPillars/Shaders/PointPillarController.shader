Shader "PointPillars/PointPillarController"
{
    Properties
    {
        _ControllerTex ("Controller", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
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
            Texture2D<float> _ControllerTex;
            Texture2D<float> _LayersTex;
            float4 _ControllerTex_TexelSize;
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

                uint2 px = i.uv.xy * _ControllerTex_TexelSize.zw;
                float sortInputLoop = _ControllerTex[txSortInputLoop];
                float sortConfLoop = _ControllerTex[txSortConfLoop];
                float layerThread = _ControllerTex[txLayerThread];
                float layerHash = _ControllerTex[txLayerHash];
                float counters[2] =
                {
                    _ControllerTex[txLayerCounter0],
                    _ControllerTex[txLayerCounter1]
                };

                float col = 0.0;

                sortInputLoop = (_Time.y < 0.1) ?
                    MAX_LOOP : mod(sortInputLoop + 1.0, MAX_LOOP + 1.0);

                layerThread = sortInputLoop == MAX_LOOP ?
                    mod(layerThread + 1.0, 2.0) : layerThread;
                layerThread = (_Time.y < 0.1) ? 0.0 : layerThread;

                [unroll]
                for (int i = 0; i < 2; i++)
                {
                    counters[i] = (counters[i] >= MAX_LAYERS) ?
                        MAX_LAYERS : counters[i] + 1.0;
                    counters[i] = (_Time.y < 0.1) ?
                        MAX_LAYERS : counters[i];
                    if ((int) layerThread == i && sortInputLoop == MAX_LOOP)
                    {
                        counters[i] = 0.0;
                    }
                }

                layerHash = primes[(uint) counters[0]] * primes[(uint) counters[1]];

                sortConfLoop = (_Time.y < 0.1) ?
                    2.0 : mod(sortConfLoop + 1.0, MAX_CONF_LOOP + 1.0);

                float predictCount = 0.0;
                float conf = _LayersTex[layerPos2[23].xy];
                while (conf > 0.0 && predictCount <= 100)
                {
                    predictCount = predictCount + 1;
                    conf = _LayersTex[layerPos2[23] + int2(predictCount, 0)];
                }

                // buffer[0] = float4
                // (
                //     _LayersTex[layerPos2[23] + int2(0, 0)],
                //     _LayersTex[layerPos2[23] + int2(1, 0)],
                //     _LayersTex[layerPos2[23] + int2(2, 0)],
                //     _LayersTex[layerPos2[23] + int2(3, 0)]
                // );

                //buffer[0] = predictCount;

                StoreValue(txLayerCounter0, counters[0], col, px);
                StoreValue(txLayerCounter1, counters[1], col, px);
                StoreValue(txLayerThread, layerThread, col, px);
                StoreValue(txLayerHash, layerHash, col, px);
                StoreValue(txSortInputLoop, sortInputLoop, col, px);
                StoreValue(txSortConfLoop, sortConfLoop, col, px);
                StoreValue(txPredictCount, predictCount, col, px);
                return col;
            }
            ENDCG
        }
    }
}