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

            #define time _Time.g

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
            float4 _Color1;
            float4 _Color2;

            #define PI 3.1415//radians(180.)

            // fixed2x2 rotate(fixed angle)
            // {
            // 	return fixed2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
            // }

            fixed3 HueShift (in fixed3 Color, in fixed Shift)
            {
                const fixed3 P = fixed3(0.55735,0.55735,0.55735)*dot(fixed3(0.55735,0.55735,0.55735),Color);
                const fixed3 U = Color-P;
                const fixed3 V = cross(fixed3(0.55735,0.55735,0.55735),U);    
                Color = U*cos(Shift*6.2832) + V*sin(Shift*6.2832) + P;
                return Color;
            }

            [maxvertexcount(3)]
            void geom(point v2g IN[1], inout TriangleStream<g2f> outStream, uint primitiveID : SV_PrimitiveID)
            {
                uint2 idUV;
                idUV.x = primitiveID % 512;
                idUV.y = primitiveID / 512;

                float3 pos = _MainTex[idUV];

                if (all(pos == 0..xxx)) return;

                float4 centerColor = float4(0, 0, 0, 1.0);

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
