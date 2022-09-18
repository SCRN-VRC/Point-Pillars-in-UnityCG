/*
    The model uses 6 key features to represent each point per pillar.
    This layer concatenates all 6 features with the 3 original points.
*/

Shader "PointPillars/Embedding"
{
    Properties
    {
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _WeightsTex ("Baked Weights", 2D) = "black" {}
        _CoordsTex ("Grid Coords Texture", 2D) = "black" {}
        _CounterTex ("Counter Texture", 2D) = "black" {}
        _LayersTex ("Layers Texture", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+4" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        Blend Off
        Cull Front

        Pass
        {
            Lighting Off
            SeparateSpecular Off
            ZTest Always
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

            //RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float4> _CoordsTex;
            Texture2D<float> _LayersTex;
            Texture2D<float> _WeightsTex;
            Texture2D<float> _ControllerTex;
            Texture2D<float> _CounterTex;
            float4 _CoordsTex_TexelSize;
            float4 _LayersTex_TexelSize;
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

                uint2 px = i.uv.xy * _LayersTex_TexelSize.zw;
                uint4 renderPos = layerPos1[5];
                bool renderArea = insideArea(renderPos, px);
                clip(renderArea ? 1.0 : -1.0);
                
                float col = _LayersTex[px];
                uint layerHash = _ControllerTex[txLayerHash];

                if (layerHash % primes[2] == 0)
                {
                    px -= renderPos.xy;

                    uint id = getIDs(_LayersTex, px % layerPos1[4].zw);
                    if (id == 0) return 0;

                    uint n = px.x / layerPos1[4].z;
                    uint m = px.y / layerPos1[4].w;

                    // only use the point max count per voxel from the first point

                    uint2 idUV;

                    id = id - 1;
                    idUV.x = id % layerPos1[2].z;
                    idUV.y = id / layerPos1[2].z;
                    
                    uint2 coords = _CoordsTex[idUV];
                    uint num_points = min(_CounterTex[coords], MAX_POINTS);

                    // subsequent m+ points will overflow to next voxel, resulting
                    // in wrong point count

                    id = id + m;
                    idUV.x = id % layerPos1[2].z;
                    idUV.y = id / layerPos1[2].z;

                    float s = 0.0;

                    if (m < num_points)
                    {
                        /*
                            From Point Pillars paper:
                            The points in each pillar are then
                            decorated (augmented) with r, xc, yc, zc, xp, yp where r
                            is reflectance, the c subscript denotes distance to the arith-
                            metic mean of all points in the pillar, and the p subscript
                            denotes the offset from the pillar x, y center
                        */
                        float concat[9];
                        concat[0] = getL4(_LayersTex, idUV);
                        concat[1] = getL5(_LayersTex, idUV);
                        concat[2] = getL1(_LayersTex, uint3(idUV, 2));
                        concat[3] = getL1(_LayersTex, uint3(idUV, 3));
                        concat[4] = getL3(_LayersTex, uint3(idUV, 0));
                        concat[5] = getL3(_LayersTex, uint3(idUV, 1));
                        concat[6] = getL3(_LayersTex, uint3(idUV, 2));
                        concat[7] = concat[0];
                        concat[8] = concat[1];

                        for (uint i = 0; i < 9; i++)
                        {
                            s += concat[i] * getConst(_WeightsTex, 0, uint2(i, n));
                        }

                        // if (all(px == uint2(458, 1165)))
                        // {
                        //     buffer[0] = float4(idUV, 0, 0);
                        // }
                    }

                    s = batchNorm(
                        s,
                        getConst(_WeightsTex, 1, uint2(n, 0)),
                        getConst(_WeightsTex, 2, uint2(n, 0)),
                        getMeanVar(_WeightsTex, 0, n),
                        getMeanVar(_WeightsTex, 1, n));

                    s = relu(s);

                    return s;
                }
                return col;
            }
            ENDCG
        }
    }
}