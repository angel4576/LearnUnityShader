Shader "Custom/ToonShader2"
{
    Properties
    {
        [Header(Texture)]
        [Space(5)]
        _MainTex ("Texture", 2D) = "white" {}
        _LightMap ("LightMap", 2D) = "white" {}
        
        _BrightThreshold ("Bright Threshold", Range(0, 1)) = 0.8
        _MiddleThreshold ("Middle Threshold", Range(0, 1)) = 0.5
        _DarkThreshold ("Dark Threshold", Range(0, 1)) = 0.3
        _Smoothness ("Smoothness", Range(0, 0.5)) = 0.1
        
        [Header(Specular)]
        [Space(5)]
        _Roughness ("Roughness", Range(0, 1)) = 0.1
        _SpecThreshold ("Specular Threshold", Range(0, 1)) = 0.1
        
        [Header(Boundary)]
        [Space(5)]
//        _BoundaryMin ("Boundary Min", Range(0, 0.5)) = 0.1
//        _BoundaryMax ("Boundary Max", Range(0, 0.5)) = 0.2
        _BoundarySmoothness ("Boundary Smoothness", Range(0, 0.5)) = 0.1
        _BoundaryColor ("Boundary Color", Color) = (1,1,1)
        
        [Toggle(IS_YUANSHEN)]_IsYuanshen ("Is yuanshen model", float) = 0 // ?
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local_fragment IS_YUANSHEN

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #define PI 3.14159265359
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _LightMap;
            float4 _LightMap_ST;

            half _BrightThreshold;
            half _MiddleThreshold;
            half _DarkThreshold;
            half _SpecThreshold;
            
            half _Smoothness;
            half _Roughness;

            half _BoundarySmoothness;
            half3 _BoundaryColor;

             // Fresnel Equation
            float3 FresnelSchlick(float VdotN, float3 F0){
                return F0 + (1 - F0) * pow((1.0 - VdotN), 5);
                // return F0 + (1 - F0) * exp2((-5.55473 * hDotV - 6.98316) * hDotV);
            }

            // NDF
            float DistributionGGX(float NDotH, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float denom = NDotH * NDotH * (a2 - 1) + 1; // denominator
                denom = denom * denom * PI;

                return a2 / denom;
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldDir(v.normal);

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 mainTexColor = tex2D(_MainTex, i.uv);
                
                float3 nDir = normalize(i.worldNormal);
                float3 lDir = normalize(UnityWorldSpaceLightDir(_WorldSpaceLightPos0.xyz)); // light dir
                float3 vDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz)); // view dir
                float3 hDir = normalize(vDir + lDir);
                
                // Lambert
                float NDotL = max(0, dot(nDir, lDir));

                float HDotV = max(0, dot(hDir, vDir));
                float VDotN = max(0, dot(vDir, nDir));
                float NDotH = max(0, dot(nDir, hDir));

                half brightSmooth = smoothstep(_BrightThreshold-_Smoothness, _BrightThreshold+_Smoothness, NDotL);
                half midSmooth = smoothstep(_MiddleThreshold-_Smoothness, _MiddleThreshold+_Smoothness, NDotL);
                half darkSmooth = smoothstep(_DarkThreshold-_Smoothness, _DarkThreshold+_Smoothness, NDotL);

                // Light and shadow boundary
                // half brightSmooth2 = 1 - brightSmooth;
                half boundSmooth = smoothstep(_BrightThreshold-_BoundarySmoothness, _BrightThreshold+_BoundarySmoothness, NDotL);
                half boundSmooth2 = smoothstep(_BrightThreshold+_BoundarySmoothness, _BrightThreshold-_BoundarySmoothness, NDotL); // reverse interpolate
                half boundFactor = boundSmooth * boundSmooth2;
                
                fixed3 boundColor = _BoundaryColor * boundFactor;
                
                // Window / light intensity range
                half brightWin = brightSmooth;
                half midBrightWin = midSmooth - brightSmooth; // avoid overlap
                half midDarkWin = darkSmooth - midSmooth;
                half darkWin = 1 - darkSmooth; // 4 win sum = 1

                half intensity = brightWin * 1.0 + midBrightWin * 0.8 + midDarkWin * 0.5 + darkWin * 0.3; // <= 1
                
                // half intensity = NDotL > _BrightThreshold ? 1.0 : NDotL > _MiddleThreshold ? 0.8 :
                // NDotL > _DarkThreshold ? 0.5 : 0.3;
                
                // Fresnel for rim light
                float3 fresnelFactor = FresnelSchlick(VDotN, float3(0.04, 0.04, 0.04)); // basic reflect rate

                // Diffuse
                intensity = intensity + fresnelFactor; // diffuse * intensity + diffuse * fresnel
                fixed3 diffuse = mainTexColor.rgb * _LightColor0.rgb * intensity;

                // LightMap
                fixed3 lightMapColor = tex2D(_LightMap, i.uv);
                #if IS_YUANSHEN
                    fixed specFactor = lightMapColor.b;
                    fixed smoothness = lightMapColor.r; // use this channel as smoothness
                #else
                    fixed specFactor = lightMapColor.r;
                    fixed smoothness = lightMapColor.b;
                #endif

                fixed roughness = 1.0 - smoothness;

                // Specular
                float NDF = DistributionGGX(NDotH, _Roughness); // control spec intensity
                float maxSpecIntensity = DistributionGGX(1.0, _Roughness);
                //float maxSpecIntensity = DistributionGGX(1.0, roughness);
                float specThreshold = maxSpecIntensity * _SpecThreshold;
                half specSmooth = smoothstep(specThreshold-_Smoothness, specThreshold+_Smoothness, NDF);
                fixed3 specular = specSmooth * (maxSpecIntensity+specThreshold) * 0.5; // specSmooth * NDF

                specular *= specFactor;
                
                fixed3 finalColor = diffuse + specular/*+ boundColor + specular*/ ;
                //finalColor = smoothness;
                
                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}
