Shader "Custom/ParallaxMapShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _HeightMap ("Texture", 2D) = "white" {}
        _HeightScale ("Height Scale", Range(0, 0.2)) = 0

        // steep parallax mapping
        _MaxLayerNum ("Max Layer Number", float) = 1
        _MinLayerNum ("Min Layer Number", float) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                // UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worldBiTangent : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _HeightMap;
            float4 _HeightMap_ST;

            float _HeightScale;

            float _MaxLayerNum;
            float _MinLayerNum;

            float2 ParallaxMapping(float2 uv, float3 vDir)
            {
                fixed height = tex2D(_HeightMap, uv).r * _HeightScale;
                // 往视野的xy方向根据高度值偏移
                // 除以z以应用z分量的影响（视野越垂直，z分量越大，偏移越小）
                float2 uvOffset = height * (vDir.xy /*/ vDir.z*/);

                return uv + uvOffset;
            }

            float2 SteepParallaxMapping(float2 uv, float3 vDir)
            {
                // 优化：根据视角来决定分层数(因为视线方向越垂直于平面，纹理偏移量较少，不需要过多的层数来维持精度)
                float layerNum = lerp(_MaxLayerNum, _MinLayerNum, dot(float3(0, 0, 1), vDir));
                float layerDepth = 1.0f / layerNum;
                float2 deltaTexcoords = 0; // 层深对应偏移量

                deltaTexcoords = vDir.xy / layerNum * _HeightScale; // z轴总深为1 每层偏移1/layerNum; xy方向总深为viewDir(归一化) 每层偏移v/layerNum
                float2 currentTexcoord = uv;
                float currentSampleDepth = tex2D(_HeightMap, currentTexcoord).r; // 当前纹理坐标采样结果
                float currentLayerDepth = 0; // 当前层的深度

                [unroll(100)] // 完全展开循环 限制循环次数（100）
                while(currentLayerDepth < currentSampleDepth)
                {
                    currentTexcoord += deltaTexcoords;
                    currentSampleDepth = tex2D(_HeightMap, currentTexcoord).r;
                    currentLayerDepth += layerDepth;
                }

                return currentTexcoord;

            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBiTangent = normalize(cross(o.worldNormal, o.worldTangent) * v.tangent.w);

                // UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3x3 tangentTrans = transpose(float3x3(i.worldTangent, i.worldBiTangent, i.worldNormal));
                float3 vDir = UnityWorldSpaceViewDir(i.worldPos);
                vDir = normalize(vDir);
                float3 vDirTan = mul(tangentTrans, vDir);
                vDirTan = normalize(vDirTan);

                // i.uv = ParallaxMapping(i.uv, vDirTan);
                i.uv = SteepParallaxMapping(i.uv, vDirTan);

                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                return col;
            }
            ENDCG
        }
    }
}
