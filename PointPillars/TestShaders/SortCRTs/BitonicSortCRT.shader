Shader "PointPillars/BitonicSortCRT"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _IndexOffset ("Index Offset", Int) = 0
    }

    SubShader
    {
        Lighting Off
        Blend One Zero

        Pass
        {
            Name "Bitonic Sort"
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 5.0

            #include "BitonicInclude.cginc"

            Texture2D<float> _ControllerTex;
            Texture2D<float4> _LayersTex;
            float4 _LayersTex_TexelSize;
            uint _IndexOffset;

            float4 frag(v2f_customrendertexture IN) : COLOR
            {
                uint loopCount = _ControllerTex[txLoopCounter];
                uint2 px = IN.localTexcoord.xy * _LayersTex_TexelSize.zw;

                uint flip = flipArray[loopCount * 9 + _IndexOffset];
                uint disperse = disperseArray[loopCount * 9 + _IndexOffset];

                if (loopCount >= LOOP_END)
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

                    float cdata = l > i ? _LayersTex[px].x : _LayersTex[tg].x;
                    float tdata = l > i ? _LayersTex[tg].x : _LayersTex[px].x;

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