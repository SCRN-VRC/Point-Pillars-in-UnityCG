Shader "PointPillars/BitonicSortCRTController"
{
    Properties
    {

    }

    SubShader
    {
        Lighting Off
        Blend One Zero

        Pass
        {
            Name "Bitonic Controller"
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 5.0

            #include "BitonicInclude.cginc"

            float4 _SelfTexture2D_TexelSize;

            float frag(v2f_customrendertexture IN) : COLOR
            {
                float loopCount = tex2D(_SelfTexture2D, txLoopCounter / _SelfTexture2D_TexelSize.zw);
                uint2 px = IN.localTexcoord.xy * _SelfTexture2D_TexelSize.zw;

                float col = 0.0;

                loopCount = (loopCount < LOOP_END * 10) ? loopCount + 1.0 : 0.0;

                StoreValue(px, loopCount, col, txLoopCounter);
                return col;
            }
            ENDCG
        }
    }
}