//
//												██╗_██████╗__██████╗_██╗
//												██║██╔═══██╗██╔═══██╗██║
//												██║██║___██║██║___██║██║
//												██║██║___██║██║___██║██║
//												██║╚██████╔╝╚██████╔╝██║
//												╚═╝_╚═════╝__╚═════╝_╚═╝
//												________________________
//

Shader "PointPillars/Display/GPUParticles"
{
    Properties
    {
        _MainTex ("RenderTex", 2D) = "black" {}
        _ParticleTex ("Particle Texture", 2D) = "white" {}
        _Size ("Pixel Size", Float) = 1.0
        _MinSize ("Minimum Size", Float) = 0.0001
        _MaxSize ("Maximum Size", Float) = 0.001
        _Scale ("Heatmap Scale", Range(0.1, 10)) = 1.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "ForceNoShadowCasting"="True" }
        LOD 100
        //Blend SrcAlpha OneMinusSrcAlpha // Traditional transparency
        //Blend One OneMinusSrcAlpha // Premultiplied transparency
        //Blend One One // Additive
        //Blend OneMinusDstColor One // Soft Additive
        //Blend DstColor Zero // Multiplicative
        //Blend DstColor SrcColor // 2x Multiplicative
        //Blend SrcAlpha One
        Blend SrcAlpha OneMinusSrcAlpha // Traditional transparency
        ZWrite Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom

            #include "UnityCG.cginc"

            struct appdata
            {
                //float4 vertex : POSITION;
                //float2 uv : TEXCOORD0;
            };

            struct v2g
            {
                //float2 uv : TEXCOORD0;
                //float4 vertex : POSITION;
            };

            struct g2f
            {
                float4 color : COLOR;
                float4 vertex : SV_POSITION;
                float2 uv :  TEXCOORD0;
            };

            v2g vert (appdata v)
            {
            }

            Texture2D<float4> _MainTex;
            float4 _MainTex_TexelSize;
            sampler2D_float _ParticleTex;
            float _Size;
            float _MinSize;
            float _MaxSize;
            float _Scale;

            float3 viridis_quintic( float x )
            {
                x = saturate( x );
                float4 x1 = float4( 1.0, x, x * x, x * x * x ); // 1 x x2 x3
                float4 x2 = x1 * x1.w * x; // x4 x5 x6 x7
                return float3(
                    dot( x1.xyzw, float4( +0.280268003, -0.143510503, +2.225793877, -14.815088879 ) ) + dot( x2.xy, float2( +25.212752309, -11.772589584 ) ),
                    dot( x1.xyzw, float4( -0.002117546, +1.617109353, -1.909305070, +2.701152864 ) ) + dot( x2.xy, float2( -1.685288385, +0.178738871 ) ),
                    dot( x1.xyzw, float4( +0.300805501, +2.614650302, -12.019139090, +28.933559110 ) ) + dot( x2.xy, float2( -33.491294770, +13.762053843 ) ) );
            }

            float3 inferno_quintic( float x )
            {
                x = saturate( x );
                float4 x1 = float4( 1.0, x, x * x, x * x * x ); // 1 x x2 x3
                float4 x2 = x1 * x1.w * x; // x4 x5 x6 x7
                return float3(
                    dot( x1.xyzw, float4( -0.027780558, +1.228188385, +0.278906882, +3.892783760 ) ) + dot( x2.xy, float2( -8.490712758, +4.069046086 ) ),
                    dot( x1.xyzw, float4( +0.014065206, +0.015360518, +1.605395918, -4.821108251 ) ) + dot( x2.xy, float2( +8.389314011, -4.193858954 ) ),
                    dot( x1.xyzw, float4( -0.019628385, +3.122510347, -5.893222355, +2.798380308 ) ) + dot( x2.xy, float2( -3.608884658, +4.324996022 ) ) );
            }

            float3 magma_quintic( float x )
            {
                x = saturate( x );
                float4 x1 = float4( 1.0, x, x * x, x * x * x ); // 1 x x2 x3
                float4 x2 = x1 * x1.w * x; // x4 x5 x6 x7
                return float3(
                    dot( x1.xyzw, float4( -0.023226960, +1.087154378, -0.109964741, +6.333665763 ) ) + dot( x2.xy, float2( -11.640596589, +5.337625354 ) ),
                    dot( x1.xyzw, float4( +0.010680993, +0.176613780, +1.638227448, -6.743522237 ) ) + dot( x2.xy, float2( +11.426396979, -5.523236379 ) ),
                    dot( x1.xyzw, float4( -0.008260782, +2.244286052, +3.005587601, -24.279769818 ) ) + dot( x2.xy, float2( +32.484310068, -12.688259703 ) ) );
            }

            float3 plasma_quintic( float x )
            {
                x = saturate( x );
                float4 x1 = float4( 1.0, x, x * x, x * x * x ); // 1 x x2 x3
                float4 x2 = x1 * x1.w * x; // x4 x5 x6 x7
                return float3(
                    dot( x1.xyzw, float4( +0.063861086, +1.992659096, -1.023901152, -0.490832805 ) ) + dot( x2.xy, float2( +1.308442123, -0.914547012 ) ),
                    dot( x1.xyzw, float4( +0.049718590, -0.791144343, +2.892305078, +0.811726816 ) ) + dot( x2.xy, float2( -4.686502417, +2.717794514 ) ),
                    dot( x1.xyzw, float4( +0.513275779, +1.580255060, -5.164414457, +4.559573646 ) ) + dot( x2.xy, float2( -1.916810682, +0.570638854 ) ) );
            }

            [maxvertexcount(3)]
            void geom(point v2g IN[1], inout TriangleStream<g2f> outStream, uint primitiveID : SV_PrimitiveID)
            {
                uint2 idUV;
                idUV.x = primitiveID % 512;
                idUV.y = primitiveID / 512;

                float4 pos = _MainTex[idUV];
                pos.xyz = float3(-pos.y, pos.z, pos.x);

                if (all(pos.xyz == 0..xxx)) return;

                float4 centerColor = float4(viridis_quintic(pow(pos.w, 2) * _Scale), 1.0);

                float4 clipPos = UnityObjectToClipPos(float4(pos.xyz, 1));
                float dx = (_Size ) / _ScreenParams.x * clipPos.w;
                float dy = (_Size ) / _ScreenParams.y * clipPos.w;
                dx = clamp(dx, _MinSize, _MaxSize);
                dy = clamp(dy, _MinSize, _MaxSize) * _ScreenParams.x / _ScreenParams.y;

                g2f OUT;
                OUT.vertex = clipPos + float4(-dx,-dy,0,0); OUT.color = centerColor; OUT.uv = float2(0, 0); outStream.Append(OUT);
                OUT.vertex = clipPos + float4( dx * 2,-dy,0,0); OUT.color = centerColor; OUT.uv = float2(2, 0); outStream.Append(OUT);
                OUT.vertex = clipPos + float4(-dx, dy * 2,0,0); OUT.color = centerColor; OUT.uv = float2(0, 2); outStream.Append(OUT);
                outStream.RestartStrip();
            }

            fixed4 frag (g2f i) : SV_Target
            {
                float4 col = tex2D(_ParticleTex, i.uv);
                clip(col.a - 0.01);
                return i.color * col.a;
            }
            ENDCG
        }
    }
}
