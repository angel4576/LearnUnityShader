Shader "Custom/NPR/ImproveTwoTone"
{
    Properties
    {
        [Header(Outline Setting)]
        [Space(5)]
	    _OutlineWidth ("Outline Width", Range(0.01, 1)) = 0.24
        _OutLineColor ("OutLine Color", Color) = (0.5,0.5,0.5,1)
        
        [Header(Texture)]
        [Space(5)]
        _MainTex ("Texture", 2D) = "white" {}
        _LightMap ("LightMap", 2D) = "white" {}
        _NormalMap ("NormalMap", 2D) = "white" {}
        _VCMap ("VC Map", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1) 
        
        [Header(Diffuse)]
        [Space(5)]
        _BrightThreshold ("Bright Threshold", Range(0, 1)) = 0.8
        _MiddleThreshold ("Middle Threshold", Range(0, 1)) = 0.5
        _DarkThreshold ("Dark Threshold", Range(0, 1)) = 0.3
        _DarkColor ("Dark Color", Color) = (1, 1, 1)
        _DeepDarkColor ("Deep Dark Color", Color) = (1, 1, 1) 
        _Smoothness ("Boundary Smoothness", Range(0, 0.5)) = 0.1
        _AOWeight ("AO Weight", Range(0, 1)) = 1
        _DiffuseBright ("Diffuse Brightness", Range(0, 1)) = 0
        
        [Header(Specular)]
        [Space(5)]
        _Roughness ("Roughness", Range(0, 1)) = 0.1
        _SmoothnessFactor ("Smoothness Weight", Range(0, 1)) = 1
        _SpecThreshold ("Specular Threshold", Range(0, 1)) = 0.1
        
        [Header(Boundary)]
        [Space(5)]
//        _BoundaryMin ("Boundary Min", Range(0, 0.5)) = 0.1
//        _BoundaryMax ("Boundary Max", Range(0, 0.5)) = 0.2
        _BoundarySmoothness ("Boundary Smoothness", Range(0, 0.5)) = 0.1
        _BoundaryColor ("Boundary Color", Color) = (1,1,1)
        
        [Toggle(IS_YUANSHEN)]_IsYuanshen ("Is yuanshen model", float) = 0 // ?
        [Toggle(ENABLE_NORMALMAP)]_EnableNormalmap ("Enable NormalMap", float) = 0 
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            
            Cull Back
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local_fragment IS_YUANSHEN
            #pragma shader_feature_local_fragment ENABLE_NORMALMAP
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            #define PI 3.14159265359
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worldBitangent : TEXCOORD4;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _LightMap;
            float4 _LightMap_ST;

            sampler2D _NormalMap;
            float4 _NormalMap_ST;

            sampler2D _VCMap;

            fixed3 _Color;
            
            half _BrightThreshold;
            half _MiddleThreshold;
            half _DarkThreshold;
            half _SpecThreshold;

            fixed3 _DarkColor;
            fixed3 _DeepDarkColor;
            
            half _Smoothness;
            half _Roughness;
            float _SmoothnessFactor;
            float _AOWeight;
            half _DiffuseBright;

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

            float warp(float x, float w)
            {
                return (x + w) / (1 + w);
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldDir(v.normal);

                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBitangent = normalize(cross(o.worldNormal, o.worldTangent) * v.tangent.w); // w is used for deciding left/right hand coordinate
                        
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 mainTexColor = tex2D(_MainTex, i.uv);
                // mainTexColor = fixed4(_Color.rgb, 1);

                fixed3 normalTex = UnpackNormal(tex2D(_NormalMap, i.uv));
                // TBN matrix
                float3x3 tangentTrans = transpose(float3x3(i.worldTangent, i.worldBitangent, i.worldNormal));  
                // Transform normal from tangent space to world space
                float3 worldNormalTex = mul(tangentTrans, normalTex);

                #if ENABLE_NORMALMAP
                    float3 nDir = normalize(worldNormalTex);
                #else
                    float3 nDir = normalize(i.worldNormal);
                #endif
                                
                float3 lDir = normalize(UnityWorldSpaceLightDir(_WorldSpaceLightPos0.xyz)); // light dir
                float3 vDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz)); // view dir
                float3 hDir = normalize(vDir + lDir);

                // LightMap
                fixed3 lightMapColor = tex2D(_LightMap, i.uv);
                fixed aoFactor = lightMapColor.g;
                fixed3 VC = tex2D(_VCMap, i.uv).g;
                
                #if IS_YUANSHEN
                    fixed specFactor = lightMapColor.b;
                    fixed smoothness = lightMapColor.r; // use this channel as smoothness
                #else
                    fixed specFactor = lightMapColor.r;
                    fixed smoothness = lightMapColor.b;
                #endif
                
                // Lambert
                aoFactor = 2.0 * aoFactor - 1.0;
                float NDotL = max(0, dot(nDir, lDir));// + aoFactor * _AOWeight;
                NDotL = 0.33 +  NDotL * 0.33; 
                
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

                // half diffuseIntensity = brightWin * 1.0 + midBrightWin * 0.8 + midDarkWin * 0.5 + darkWin * 0.3; // <= 1

                // Reconstruct light intensity
                // Small light area -> brighter
                half diffuseIntensity = brightWin * (1 + _BrightThreshold) * 0.5 // average 
                            + midBrightWin * (_BrightThreshold + _MiddleThreshold) * 0.5
                            + midDarkWin * (_MiddleThreshold + _DarkThreshold) * 0.5 * (_DarkColor.rgb * 3 / (_DarkColor.r + _DarkColor.g + _DarkColor.b))
                            + darkWin * _DarkThreshold * 0.5 * (_DeepDarkColor.rgb * 3 / (_DeepDarkColor.r + _DeepDarkColor.g + _DeepDarkColor.b));

                diffuseIntensity = warp(diffuseIntensity, _DiffuseBright);// [0,1]
                
                // half intensity = NDotL > _BrightThreshold ? 1.0 : NDotL > _MiddleThreshold ? 0.8 :
                // NDotL > _DarkThreshold ? 0.5 : 0.3;
                
                // Fresnel for rim light
                float3 fresnelFactor = FresnelSchlick(VDotN, float3(0.04, 0.04, 0.04)); // basic reflect rate
                                

                // Diffuse
                diffuseIntensity = diffuseIntensity + fresnelFactor; // diffuse * intensity + diffuse * fresnel
                fixed3 diffuse = mainTexColor.rgb * _LightColor0.rgb * diffuseIntensity;

                smoothness = 0.9 * (smoothness * _SmoothnessFactor) + 0.05; // map to [.05, .95] to avoid 0 and 1
                fixed roughness = 1.0 - smoothness;

                // Specular
                float NDF = DistributionGGX(NDotH, roughness); // control spec intensity
                //float maxSpecIntensity = DistributionGGX(1.0, _Roughness);
                float maxSpecIntensity = DistributionGGX(1.0, roughness);
                float specThreshold = maxSpecIntensity * _SpecThreshold;
                half specSmooth = smoothstep(specThreshold-_Smoothness, specThreshold+_Smoothness, NDF);
                fixed3 specular = specSmooth * (maxSpecIntensity+specThreshold) * 0.5 * _LightColor0.rgb; // specSmooth * NDF

                specular *= specFactor;
                
                fixed3 finalColor = diffuse + specular/*+ boundColor + specular*/ ;
                // finalColor = smoothness;
                
                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }

        Pass
	    {
	        Name "Outline"
	        Tags {"LightMode"="ForwardBase"}
            
            Cull Front
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            fixed _OutlineWidth;
            fixed4 _OutLineColor;

            sampler2D _MainTex;
            float4 _MainTex_ST;

            struct a2v 
	        {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 vertColor : COLOR;
                float4 tangent : TANGENT;
            };

            struct v2f
	        {
                float4 pos : SV_POSITION;
                float3 vColor : COLOR;
                float2 uv : TEXCOORD0;
            };

            v2f vert (a2v v) 
	        {
                v2f o;
		        UNITY_INITIALIZE_OUTPUT(v2f, o);
                // o.pos = UnityObjectToClipPos(float4(v.vertex.xyz + v.normal * _OutlineWidth * 0.1 ,1));//顶点沿着法线方向外扩(模型空间)
                // solution: calculate in NDC space
                float4 pos = UnityObjectToClipPos(v.vertex); // v in NDC
                // Model -> View
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal.xyz);
                // View -> NDC
                float3 ndcNormal = normalize(TransformViewToProjection(viewNormal.xyz)) /** pos.w*/;// transform normal to NDC space 
                
                // Calculate screen aspect ratio in camera space
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//将近裁剪面右上角位置的顶点变换到观察空间
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);//求得屏幕宽高比
                ndcNormal.x *= aspect;

                // outline is 2d no need to consider z (depth)
                pos.xy += ndcNormal.xy * _OutlineWidth * 0.01; // * v.vertColor.a; // use alpha to adjust width
                o.pos = pos;
                // vertex color (doesn't exist for this model)
                o.vColor = v.vertColor.rgb;

                // transmit uv
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            fixed4 frag(v2f i) : SV_TARGET 
	        {   
                fixed4 texColor = tex2D(_MainTex, i.uv);
                return fixed4(_OutLineColor.rgb * texColor.rgb, 1.0);
                // return _OutLineColor;
            }
            ENDCG
        }
    }
}
