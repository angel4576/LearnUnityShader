Shader "Custom/PBRShader"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        
        _MainTex ("Texture", 2D) = "white" {}
        [Normal]_NormalMap ("Normal Map", 2D) = "white" {}

        _HeightMap ("Height Map", 2D) = "White" {}
        _HeightScale ("Height Scale", Range(0, 1)) = 0
        _MaxLayerNum ("Max Layer Number", float) = 1
        _MinLayerNum ("Min Layer Number", float) = 2

        _MetallicMap ("Metallic Map", 2D) = "white" {}
        _Metallic ("Metallic", Range(0, 1)) = 0

        _RoughnessMap ("Roughness Map", 2D) = "white" {}
        _Roughness ("Roughness", Range(0, 1)) = 0

        _IrradianceCubemap("Irradiance CubeMap", Cube) = "_Skybox" {}
        
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", Range(1.0, 255)) = 20

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

            // #pragma shader_feature _PHONG
            // #pragma shader_feature _BLINNPHONG
            // #pragma shader_feature _ENABLE_NORMALMAP

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            #define PI 3.14159265359
            
            float4 _BaseColor;

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _NormalMap;
            float4 _NormalMap_ST;

            sampler2D _HeightMap;
            float _HeightScale;
            float _MaxLayerNum;
            float _MinLayerNum;

            sampler2D _MetallicMap;
            half _Metallic;
            sampler2D _RoughnessMap;
            half _Roughness;

            samplerCUBE _IrradianceCubemap;

            float4 _Diffuse;
            float4 _Specular;
            float _Gloss;


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

                // 视差遮挡映射
                float2 prevTexcoord = currentTexcoord - deltaTexcoords; 
                // get depth after and before collision
                float afterDepth = currentSampleDepth - currentLayerDepth; // 采样深度 - 层深
                float prevLayerDepth = currentLayerDepth - layerDepth;
                float beforeDepth = tex2D(_HeightMap, prevTexcoord).r - prevLayerDepth;

                float weight = afterDepth / (afterDepth - beforeDepth);

                float2 finalTexcoord = lerp(currentTexcoord, prevTexcoord, weight); // x * (1-s) + y * s
                // finalTexcoord = prevTexcoord * weight + currentTexcoord * (1.0 - weight);
                return finalTexcoord;
            }

            // Normal Distribution Function
            float NormalDistributionGGX(float nDotH, float roughness){
                // float nDotH = max(0, dot(n, h));
                float a = roughness * roughness;
                float a2 = a * a;
                float denom = nDotH * nDotH * (a2 - 1) + 1; // denominator
                denom = denom * denom * PI;

                return a2 / denom;
            }

            // Fresnel Equation
            float3 FresnelSchlick(float hDotV, float3 F0){
                // float hDotV = max(0, dot(h, v));
                return F0 + (1 - F0) * pow((1.0 - hDotV), 5);
                // return F0 + (1 - F0) * exp2((-5.55473 * hDotV - 6.98316) * hDotV);
            }

            // Geometry Function
            float GeometrySchlickGGX(float dotProduct, float roughness){
                // roughness的重映射
                float k = pow(roughness + 1.0, 2) / 8; // direct light
                // float nDotV = max(0, dot(n, v));
                float demom = dotProduct * (1.0 - k) + k;
                return dotProduct / max(0.00001, demom);
            }

            // ---------For indirect light-----------
            //Fresnel calulation concerning roughness
            float3 FresnelSchlickRoughness(float nDotV, float3 F0, float roughness){
                return F0 + (max(1.0 - roughness, F0) - F0) * pow(1.0 - nDotV, 5.0);
            }
            
            /*
                较低的粗糙度会选择较低的 mip 层级，反射会更清晰。
                较高的粗糙度会选择较高的 mip 层级，反射会更模糊。
            */
            float PerceptualRoughnessToMipLevel(float roughness){
                // 粗糙度的非线性处理
                roughness = roughness * (1.7 - 0.7 * roughness);
                return roughness * UNITY_SPECCUBE_LOD_STEPS; // max mip level (6)
            }

            //UE4 Black Ops II modify version
            float2 EnvBRDFApprox(float Roughness, float NoV)
            {
                // [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
                // Adaptation to fit our G term.
                const float4 c0 = {
                    - 1, -0.0275, -0.572, 0.022
                };
                const float4 c1 = {
                    1, 0.0425, 1.04, -0.04
                };
                float4 r = Roughness * c0 + c1;
                float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
                float2 AB = float2(-1.04, 1.04) * a004 + r.zw;
                return AB;
            }

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
                // UNITY_INITIALIZE_OUTPUT(v2f, o);
                
                o.uv = v.texCoord; 
                
                o.pos = UnityObjectToClipPos(v.vertex); // vertex in clip space
                
                o.worldNormal = normalize(UnityObjectToWorldNormal(v.normal)); // normal in world space
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                // o.worldTangent = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0)).xyz);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBitangent = normalize(cross(o.worldNormal, o.worldTangent) * v.tangent.w); // w is used for deciding left/right hand coordinate

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the textures
                float4 mainTex = tex2D(_MainTex, i.uv) * _BaseColor;
                float3 normalTex = UnpackNormal(tex2D(_NormalMap, i.uv)); // normal in tangent space
                float roughness = tex2D(_RoughnessMap, i.uv).r * _Roughness;
                // roughness = max(PerceptualRoughnessToRoughness(roughness), 0.002);
                float metallic = tex2D(_MetallicMap, i.uv).r * _Metallic;

                float3 finalColor;
                
                // TBN matrix
                float3x3 tangentTrans = transpose(float3x3(i.worldTangent, i.worldBitangent, i.worldNormal));  
                // Transform normal from tangent space to world space
                float3 worldNormalTex = mul(tangentTrans, normalTex);

                // float3 nDir = normalize(i.worldNormal);
                float3 nDir = normalize(worldNormalTex); // normals from normal map
                // float3 lDir = normalize(_WorldSpaceLightPos0.xyz); // light direction
                float3 lDir = normalize(UnityWorldSpaceLightDir(i.worldPos.xyz));
                // float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos); // view direction
                float3 vDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz));
                float3 hDir = normalize(lDir + vDir); // half vector
                
                /*
                    PBR
                */

                float nDotH = max(0, dot(nDir, hDir));
                float nDotV = max(0, dot(nDir, vDir));
                float hDotV = max(0, dot(hDir, vDir));
                float nDotL = max(0, dot(nDir, lDir));
                
                // -------------- Direct Light ---------------
                // Directional light diffuse
                float3 DirectDiffuse =  mainTex * _LightColor0.rgb * nDotL;
                // DirectDiffuse = mainTex * nDotL;

                // Directional light specular
                float3 F0 = lerp(float3(0.04, 0.04, 0.04), mainTex.rgb, metallic);
                float D = NormalDistributionGGX(nDotH, roughness);
                float3 F = FresnelSchlick(hDotV, F0);
                float Gv = GeometrySchlickGGX(nDotV, roughness);
                float Gl = GeometrySchlickGGX(nDotL, roughness);
                float G = Gv * Gl;
                
                // Specular BRDF
                float3 specular = D * F * G / (4 * nDotV * nDotL + 0.00001) ;
                float3 DirectSpecular = specular * _LightColor0.rgb * nDotL;

                float3 ks = F;
                float3 kd = (1.0 - ks) * (1.0 - metallic); // non-metal: metallic low, kd high; 

                // finalColor = (kd * DirectDiffuse + specular) * _LightColor0.rgb * nDotL;
                float3 directLight = kd * DirectDiffuse + DirectSpecular;


                // -------------- Indirect Light --------------- 有时间再研究一下
                float3 irradiance = texCUBE(_IrradianceCubemap, nDir).rgb;
                float3 indirectDiffuse = 0; // = irradiance * mainTex;

                float3 ks_indirect = FresnelSchlickRoughness(nDotV, F0, roughness);
                float3 kd_indirect = (1 - ks_indirect) * (1 - metallic);

                
                // Spherical Harmonics
                float3 irradianceSH = ShadeSH9(float4(nDir, 1.0));
                indirectDiffuse = kd_indirect * irradianceSH * mainTex;
                
                // Calculate mip level based on roughness
                float mipLevel = PerceptualRoughnessToMipLevel(roughness);

                // Cubemap
                float3 rDir = normalize(reflect(-vDir, nDir)); // ? WHY V
                half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, rDir, mipLevel); // sample cubemap in specCube0 (hdr code)
                // decode to rgb
                // 贴图的预过滤颜色
                float3 prefilteredColor = DecodeHDR(rgbm, unity_SpecCube0_HDR); // specCube0_HDR: if cubemap activates hdr code
                
                // Environment approximation of specular BRDF LUT
                float2 envApprox = EnvBRDFApprox(roughness, nDotV);
                
                float3 indirectSpecular = ks_indirect * envApprox.x + envApprox.y;
                // indirectSpecular *= prefilteredColor;
                
                // indirect light final result
                float3 indirectLight = indirectDiffuse + prefilteredColor * indirectSpecular;

                finalColor = directLight + indirectLight;
                // finalColor = prefilteredColor;
                

                /*
                // Phong Shading
                
                // Phong Diffuse
                float nDotL = dot(nDir, lDir); 
                float3 diffuse = _LightColor0.rgb * mainTex * max(0, nDotL);
                
                // Phong Specular
                float3 rDir = normalize(reflect(-lDir, nDir));
                float vDotR = dot(vDir, rDir);

                float3 specular = _Specular * pow(max(0, vDotR), _Gloss);

                // Simple Ambient
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * mainTex;
                
                finalColor = ambient + diffuse + specular;
                */


                return float4(finalColor, 1.0);

            }
            ENDCG
        }
    }
}
