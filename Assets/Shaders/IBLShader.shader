Shader "Custom/IBLShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _EnvCubemap("Environment CubeMap", Cube) = "_Skybox" {}
        _EnvScale("Environment Scale", Range(0, 1)) = 0.5
        _Gloss("Gloss", Range(0, 1)) = 0.5
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

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            samplerCUBE _EnvCubemap;
            float _EnvScale;
            float _Gloss;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
                
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                float3 vDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz));
                float3 lDir = normalize(UnityWorldSpaceLightDir(i.worldPos.xyz));
                // reflect
                float3 rDir = reflect(-vDir, i.worldNormal);

                float nDotL = max(0, dot(i.worldNormal, lDir));
                float3 diffuseCol = _LightColor0.rgb * col.rgb * (0.5 * nDotL + 0.5);

                // sample cubemap using reflect direction
                half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, rDir, 0);
                float3 reflCol = DecodeHDR(rgbm, unity_SpecCube0_HDR) * _EnvScale;
                
                // float3 reflCol = texCUBE(_EnvCubemap, rDir).rgb * _EnvScale;
                reflCol = lerp(diffuseCol * reflCol, reflCol, _Gloss);
                
                float3 finalColor = diffuseCol + reflCol;

                return fixed4(reflCol, 1);
            }
            ENDCG
        }
    }
}
