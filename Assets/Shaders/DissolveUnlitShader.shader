Shader "Custom/DissolveUnlitShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)

        _MainTex ("Texture", 2D) = "red" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _DissolveThreshold ("Dissolve Threshold", Range(0, 1)) = 0.5
        _EdgeWidth ("Edge Width", Range(0, 0.5)) = 0.1 
        _EdgeColor ("Edge Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags 
        { 
            "Queue"="Transparent"
            "RenderType"="Transparent" 
        }
        LOD 100
        // ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {   
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

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
                float3 worldNormal : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };
            
            fixed4 _Color;

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;

            fixed _DissolveThreshold;
            fixed _EdgeWidth;
            fixed4 _EdgeColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.worldNormal = normalize(UnityObjectToWorldNormal(v.normal));

                o.uv = TRANSFORM_TEX(v.uv, _NoiseTex);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 baseColor = tex2D(_MainTex, i.uv);
                fixed noise = tex2D(_NoiseTex, i.uv).r;

                fixed3 lDir = normalize(UnityWorldSpaceLightDir(i.worldPos.xyz));
                fixed3 nDir = i.worldNormal;

                // diffuse
                fixed NDotL = max(0, dot(nDir, lDir));
                float3 diffuse = baseColor.rgb * _LightColor0.rgb * (NDotL * 0.5 + 0.5);
                
                // lerp edge color
                fixed dissolveFactor = smoothstep(_DissolveThreshold - _EdgeWidth, _DissolveThreshold, noise);
                fixed3 lerpColor = lerp(diffuse, _EdgeColor.rgb, dissolveFactor);
                
                // noise > threshold -> dissolve (alpha = 0)
                fixed alpha = step(noise, _DissolveThreshold);
                // fixed edge color
                fixed alpha2 = step(noise, _DissolveThreshold - _EdgeWidth);
                fixed edgeAlpha = alpha - alpha2; // dissolve less - dissolve more 
                fixed3 edgeColor = edgeAlpha * _EdgeColor;

                fixed4 finalColor;
                //finalColor = float4(edgeColor + diffuse, alpha2);
                finalColor = float4(lerpColor, alpha);
                return finalColor;
            }
            ENDCG
        }
    }
}
