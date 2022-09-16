/*
    Save a reference to the starting point of the group of points in
    each pillar
*/

Shader "PointPillars/IDs"
{
    Properties
    {
        _DataTex ("Output Texture", 2D) = "black" {}
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
        Blend Off

        Pass
        {
            ZTest Off

            CGPROGRAM
            #pragma vertex empty
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 5.0

            //RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D _DataTex;
            Texture2D<float4> _LayersTex;
            Texture2D<float> _ActiveTexelMap;
            float4 _DataTex_TexelSize;
            float4 _LayersTex_TexelSize;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float data : TEXCOORD0;
            };
            
            void empty() {}

            [maxvertexcount(1)]
            void geom(triangle v2f i[3], inout PointStream<v2f> pointStream, uint triID : SV_PrimitiveID)
            {
                uint count = round((1 << 18) * _ActiveTexelMap.Load(int3(0, 0, 9)));
                //buffer[0] = count;
                if(any(_ScreenParams.xy != abs(_DataTex_TexelSize.zw)) || triID >= count)
                    return;
                v2f o;

                // go backwards from count to 0 so the first reference is 
                // written last
                uint2 IDtoXY;
                triID = count - triID - 1;
                // add 1 to avoid 0, which is ignored later
                o.data = triID + 1;
                const uint DataWidth = _LayersTex_TexelSize.z;
                IDtoXY.x = triID % DataWidth;
                IDtoXY.y = triID / DataWidth;

                float2 c = _LayersTex[IDtoXY].xy;
                // convert grid size to -1 to 1
                c.xy = ((c.xy + 0.5) / _DataTex_TexelSize.zw);
                #ifdef UNITY_UV_STARTS_AT_TOP
                c.y = 1.0 - c.y;
                #endif
                c.xy = c.xy * 2.0 - 1.0;
                o.pos = float4(c.xy, 1, 1);
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
