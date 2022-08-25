Shader "PointPillars/Counter"
{
    Properties
    {
        _DataTex ("Sparse Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _ActiveTexelMap ("Active Texel Map", 2D) = "black" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent+2000"
            "DisableBatching"="True"
        }
        Blend One One

        Pass
        {
            ZTest Off

            CGPROGRAM
            #pragma vertex empty
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 5.0

            Texture2D _DataTex;
            Texture2D<float4> _LayersTex;
            Texture2D<float> _ActiveTexelMap;
            float4 _ActiveTexelMap_TexelSize;
            float4 _LayersTex_TexelSize;
            float4 _DataTex_TexelSize;

            struct v2f
            {
                float4 pos : SV_POSITION;
            };
            
            void empty() {}

            [maxvertexcount(1)]
            void geom(triangle v2f i[3], inout PointStream<v2f> pointStream, uint triID : SV_PrimitiveID)
            {
                uint count = round((1 << 18) * _ActiveTexelMap.Load(int3(0, 0, 9)));
                if(any(_ScreenParams.xy != abs(_DataTex_TexelSize.zw)) || triID > count)
                    return;
                v2f o;
                // convert grid size to -1 to 1
                uint2 IDtoXY;
                uint DataWidth = _DataTex_TexelSize.z;
                IDtoXY.x = triID % DataWidth;
                IDtoXY.y = triID / DataWidth;
                float3 c = _LayersTex[IDtoXY];
                c.xy = (c.xy / _DataTex_TexelSize.zw) * 2.0 - 1.0;
                o.pos = float4(c.xy, 1, 1);
                pointStream.Append(o);
            }
            
            float4 frag (v2f i) : SV_Target
            {
                return 1.0;
            }
            ENDCG
        }
    }
}
