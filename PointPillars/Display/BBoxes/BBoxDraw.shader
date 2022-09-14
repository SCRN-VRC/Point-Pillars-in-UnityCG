Shader "PointPillars/Display/BBoxDraw"
{
    Properties
    {
        _ControllerTex ("Controller", 2D) = "black" {}
        _DataTex ("Data Texture", 2D) = "black"
        _Index ("Index", Int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "../../Shaders/PointPillarsInclude.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float frontFace : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float> _ControllerTex;
            Texture2D<float> _DataTex;

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(int, _Index)
            UNITY_INSTANCING_BUFFER_END(Props)

            void pR(inout float2 p, float a) {
                p = cos(a)*p + sin(a) * float2(p.y, -p.x);
            }

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = float4(0, 0, 0, 0);
                o.frontFace = 0.0;
                
                uint count = getCount(_ControllerTex);
                uint id = UNITY_ACCESS_INSTANCED_PROP(Props, _Index);

                if (id < count)
                {
                    uint cls = getPredictionClass(_DataTex, id).y;
                    switch(cls)
                    {
                        case 0: { o.color = float4(1, 0, 0, 1); break; }
                        case 1: { o.color = float4(0, 1, 0, 1); break; }
                        case 2: { o.color = float4(0, 0, 1, 1); break; }
                    }
                    o.frontFace = v.vertex.z > 0.0 ? 1.0 : 0.0;

                    float4 sizeRot = getPredictionSizeRotation(_DataTex, id);
                    float3 newVert = v.vertex.xyz * sizeRot.xyz;
                    pR(newVert.zx, sizeRot.w);

                    float3 pos = getPredictionPosition(_DataTex, id);
                    newVert += pos;
                    o.vertex = UnityObjectToClipPos(float4(newVert, 1.0));
                }

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                clip(i.color.a - 0.1);

                float2 outline = abs(i.uv - 0.5) > 0.47;
                outline.x = saturate(outline.x + outline.y);
                float cross = abs(i.uv.x - i.uv.y) < 0.03;
                cross += abs(i.uv.x - (1.0 - i.uv.y)) < 0.03;
                cross = saturate(cross) * i.frontFace;
                float4 col = i.color * saturate(outline.x + cross);
                clip(col.a - 0.99);
                return col;
            }
            ENDCG
        }
    }
}
