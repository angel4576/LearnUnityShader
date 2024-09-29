Shader "Custom/Outline"
{
    Properties
    {
        [Header(Outline Setting)]
        [Space(5)]
	    _OutlineWidth ("Outline Width", Range(0.01, 2)) = 0.24
        _OutLineColor ("OutLine Color", Color) = (0.5,0.5,0.5,1)

        [Header(Main Texture Setting)]
        [Space(5)]
        _MainTex ("MainTex", 2D) = "white" {}
        _MainColor("Main Color", Color) = (1,1,1)

        [Header(Face Setting)]
        [Space(5)]
        [Toggle(ENABLE_FACE_SHADOW_MAP)]_EnableFaceShadowMap ("Enable Face Shadow Map", float) = 0
        _Threshold("Threshold", range(0, 1)) = 0
        _FaceShadowPow("Face Shadow Pow", range(0, 1)) = 1

        [Header(Shadow Setting)]
        [Space(5)]
        _FirstShadowMulColor ("First Shadow Color", Color) = (.7, .7, .7, 1.0) // _ShadowMultColor
        _FirstShadowRange ("First Shadow Range", Range(0, 1)) = 0.5    // _ShadowArea

        _SecondShadowMulColor("Second Shadow Color", Color) = (0.5, 0.5, 0.5, 1.0)
        _SecondShadowRange("Second Shadow Range", range(0, 1)) = 0.5

        _ShadowSmooth("Shadow Smooth", Range(0, 1)) = 0.2

        [Header(Shadow Ramp)]
        [Space(5)]
        _RampTex ("RampTex", 2D) = "white" {}

        [Header(LightMap Setting)]
        [Space(5)]
        _LightMap ("LightMap", 2D) = "white" {}

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        pass
        {
           Tags {"LightMode"="ForwardBase"}
			 
            Cull Back

            // render model   
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local_fragment ENABLE_FACE_SHADOW_MAP
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
            sampler2D _MainTex; // base map
            float4 _MainTex_ST;
            half3 _MainColor;

            float _Threshold;
            float _FaceShadowPow;

            // Shadow data
	        half3 _FirstShadowMulColor;
            half _FirstShadowRange;

            half3 _SecondShadowMulColor;
            half _SecondShadowRange;

            // Ramp data
            sampler2D _RampTex;
            float4 _RampTex_ST;
            float _RampIndex; // 0 - 8

            // Lightmap
            sampler2D _LightMap;
            float4 _LightMap_ST;

            struct a2v 
	        {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
	        {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
		        float3 worldPos : TEXCOORD2; 
            };

            v2f vert(a2v v)
	        {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                // handle texture tiling & offset 
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                // Object -> World
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz; // w = 1 (no need to divide w when object -> world)

                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            half4 frag(v2f i) : SV_TARGET 
	        {
                half4 col = 1;

                // Half Lambert Calculation 
                half3 worldNormal = normalize(i.worldNormal);
                half3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz); // pos/dir of main light source
                // I = max(dot(n, l) * 0.5 + 0.5, 0)
                half halfLambert = dot(worldNormal, worldLightDir) * 0.5 + 0.5; // Intensity

                // base color
                half4 mainTex = tex2D(_MainTex, i.uv); // texture sampling

                // Light map
                half4 lightMapColor = tex2D(_LightMap, i.uv);
                half3 firstShadowColor = mainTex.rgb * _FirstShadowMulColor.rgb;
                half3 secondShadowColor = mainTex.rgb * _SecondShadowMulColor.rgb;

                // Honkai3 Shadow Color algorithm
                float sWeight = (lightMapColor.g * _MainColor.r + halfLambert) * 0.5 + 1.125; // 实在弄不明白
                
                // sFactor = 0 -> display first shadow color
                float sFactor = floor(sWeight - _FirstShadowRange);
                half3 shallowShadowColor = sFactor * mainTex.rgb + (1 - sFactor) * firstShadowColor.rgb;
                
                float sFactor2 = floor(sWeight - _SecondShadowRange);
                half3 darkShadowColor = sFactor2 * firstShadowColor.rgb + (1 - sFactor2) * secondShadowColor.rgb;


                // Ramp sampling
                // use light intensity as U
                /* 
                    9 ramps in this case
                    0.5 step
                    get center of height of each ramp
                */
                float2 rampUV = float2(halfLambert, 0.5);
                half4 ramp = tex2D(_RampTex, rampUV);

                // Final color calculation
                half4 finalColor = 1;
                float sFactorFinal = floor(lightMapColor.g * _MainColor.r + 0.9);
                // finalColor.rgb = shallowShadowColor; 
                finalColor.rgb = sFactorFinal * shallowShadowColor.rgb + (1 - sFactorFinal) * darkShadowColor.rgb; 
                
                half3 diffuse = halfLambert > _FirstShadowRange ? _MainColor : _FirstShadowMulColor.rgb;
                diffuse *= mainTex;
                col.rgb =  _LightColor0 * diffuse;

            #if ENABLE_FACE_SHADOW_MAP
                // Chara direction vector in world space
                float4 modelFront = float4(0, 0, 1, 1);
                float4 modelLeft = float4(-1, 0, 0, 1);
                
                half3 frontDir = mul(unity_ObjectToWorld, modelFront);
                half fDotLight = dot(normalize(frontDir.xz), normalize(_WorldSpaceLightPos0.xz));

                // Face shadow
                // half4 faceMapColor = tex2D(_LightMap, i.uv);
                
                // determine if need to flip map
                half3 leftDir = mul(unity_ObjectToWorld, modelLeft); 
                half lDotLight = dot(normalize(leftDir.xz), normalize(_WorldSpaceLightPos0.xz));
                half4 faceMapColor = tex2D(_LightMap, float2(i.uv.x * sign(lDotLight), i.uv.y));
                
                float threshold = 0.5 - fDotLight * 0.5; // map from [-1, 1] to [0, 1]
                half faceCol = step(threshold, pow(faceMapColor, _FaceShadowPow)); // display lightmap based on brightness on different parts
                
                half4 finalFaceColor = 1; 
                finalFaceColor.rgb = lerp(_FirstShadowMulColor * mainTex, mainTex, faceCol);

                return finalFaceColor;
            
            #endif

                return half4(1, 1, 1, 1);
                // return col;
                //return finalColor;
            }

            ENDCG
        }

        Pass
	    {
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
                float3 ndcNormal = normalize(TransformViewToProjection(viewNormal.xyz)) * pos.w;//将法线变换到NDC空间
                
                // Calculate screen aspect ratio in camera space
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//将近裁剪面右上角位置的顶点变换到观察空间
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);//求得屏幕宽高比
                ndcNormal.x *= aspect;

                // outline is 2d no need to consider z (depth)
                pos.xy += ndcNormal.xy * _OutlineWidth * 0.01 * v.vertColor.a; // use alpha to adjust width
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