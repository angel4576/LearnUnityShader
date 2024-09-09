Shader "Custom/PhongShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Normal]_NormalMap ("Normal Map", 2D) = "white" {}
        
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", Range(1.0, 255)) = 20

        [Toggle(_PHONG)] _Phong("Phong", float) = 1
        [Toggle(_BLINNPHONG)] _BlinnPhong("BlinnPhong", float) = 0
        [Toggle(_ENABLE_NORMALMAP)] _Enable_NormalMap("NormalMap", float) = 0
         
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        // LOD 100

        Pass
        {
            Tags {"LightMode"="ForwardBase"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _PHONG
            #pragma shader_feature _BLINNPHONG
            #pragma shader_feature _ENABLE_NORMALMAP

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _NormalMap;
            float4 _NormalMap_ST;

            float4 _Diffuse;
            float4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texCoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION; // 裁剪空间下的坐标
                float3 worldNormal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 worldPos : TEXCOORD1; // position in world space 
                
                float3 worldTangent : TEXCOORD2;
                float3 worldBitangent : TEXCOORD3;                

            };

            v2f vert (a2v v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                
                o.uv = v.texCoord; 
                
                o.pos = UnityObjectToClipPos(v.vertex); // vertex in clip space
                
                o.worldNormal = normalize(UnityObjectToWorldNormal(v.normal)); // normal in world space
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                // o.worldTangent = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0)).xyz);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBitangent = normalize(cross(o.worldNormal, o.worldTangent) * v.tangent.w); // ?

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 mainTex = tex2D(_MainTex, i.uv);
                float3 normalTex = UnpackNormal(tex2D(_NormalMap, i.uv)); // normal in tangent space

                float3 finalColor; 
                
                
                #if defined(_PHONG)

                    // 切线变换矩阵的转置矩阵
                    float3x3 tangentTrans = transpose(float3x3(i.worldTangent, i.worldBitangent, i.worldNormal));  
                    // 将切线空间的法线变换到世界空间
                    float3 worldNormalTex = mul(tangentTrans, normalTex);

                    // Diffuse
                    // float3 nDir = i.worldNormal;
                    float3 nDir = normalize(worldNormalTex); // normals from normal map
                    float3 lDir = normalize(_WorldSpaceLightPos0.xyz); // light direction
                    float nDotL = dot(nDir, lDir);

                    float3 diffuse = _LightColor0.rgb * mainTex * max(0, nDotL);
                    // diffuse = max(0, nDotL);
                    
                    // Specular
                    float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                    float3 rDir = normalize(reflect(-lDir, nDir));
                    float vDotR = dot(vDir, rDir);

                    float3 specular = _Specular * pow(max(0, vDotR), _Gloss);

                    // Ambient
                    float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * mainTex;
                    
                    finalColor = ambient + diffuse + specular;

                #elif defined(_ENABLE_NORMALMAP)
                    // finalColor = normalTex;
                
                #else
                    
                    // finalColor = float3(1, 1, 1);
                    
                #endif
                    
                    return float4(finalColor, 1.0);
                
            }
            ENDCG
        }
    }
}
