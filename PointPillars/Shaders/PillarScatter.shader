/*
    To encode spacial information, we move the features back into
    the grid of pillars after a few layers of convolutions
*/

Shader "PointPillars/PillarScatter"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _CoordsTex ("Grid Coords Texture", 2D) = "black" {}
        _InputTex ("Input Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent+2000"
            "DisableBatching"="True"
        }
        Blend Off

        Pass
        {
            ZTest Always

            CGPROGRAM
            #pragma vertex empty
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 5.0

            #include "PointPillarsInclude.cginc"

            //RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float4> _CoordsTex;
            Texture2D<float> _LayersTex;
            Texture2D<float> _InputTex;
            Texture2D<float> _ControllerTex;
            float4 _LayersTex_TexelSize;
            float4 _InputTex_TexelSize;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float data : TEXCOORD0;
            };
            
            void empty() {}

            [maxvertexcount(1)]
            void geom(triangle v2f i[3], inout PointStream<v2f> pointStream, uint triID : SV_PrimitiveID)
            {
                if (any(_ScreenParams.xy != abs(_LayersTex_TexelSize.zw))) return;
                //uint layerHash = _ControllerTex[txLayerHash];
                //if (layerHash % primes[3] != 0) return;

                uint2 px;
                const uint DataWidth = _InputTex_TexelSize.z;
                px.x = floor(triID % DataWidth);
                px.y = floor(triID / DataWidth);
                uint m = px.x / layerPos1[4].z;

                uint2 idUV = px % layerPos1[4].zw;
                uint id = getIDs(_InputTex, idUV);
                if (id == 0) return;

                id = id - 1;
                idUV.x = id % layerPos1[2].z;
                idUV.y = id / layerPos1[2].z;
                
                float2 coords = _CoordsTex[idUV].yx;
                float data = _InputTex[layerPos1[6] + px];

                coords.x = coords.x + (float) ((m % 8) * 496);
                coords.y = coords.y + (float) ((m / 8) * 432);

                // convert grid size to -1 to 1
                coords.xy = ((coords.xy + 0.5) / _LayersTex_TexelSize.zw);
                #ifdef UNITY_UV_STARTS_AT_TOP
                coords.y = 1.0 - coords.y;
                #endif
                coords.xy = coords.xy * 2.0 - 1.0;

                v2f o;
                o.pos = float4(coords.xy, 1, 1);
                o.data = data;
                pointStream.Append(o);
            }
            
            float frag (v2f i) : SV_Target
            {
                return i.data;
            }
            ENDCG
        }
    }
}
