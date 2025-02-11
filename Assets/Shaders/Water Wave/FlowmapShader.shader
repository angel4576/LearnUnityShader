Shader "Custom/FlowmapShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _FlowMap ("Flowmap", 2D) = "white" {}
        
        _FlowIntensity ("Flow Intensity", Float) = 1.0
        _TimeSpeed ("Time Speed", Float) = 1.0
        _TimeProperty ("Time", Float) = 0.0
    }
    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _FlowMap;

            float _FlowIntensity;
            float _TimeProperty;
            float _TimeSpeed;
            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                // o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv = v.uv;
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // float2 tilingUV = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                
                float3 flowDir = tex2D(_FlowMap, i.uv) * 2.0 - 1.0; // map [0, 1] to [-1, 1]
                flowDir *= _FlowIntensity; // apply flow intensity
                
                // float phase = frac(_TimeProperty); // cause discontinuous jump
                
                // 构造两个相位相差半个周期的波形
                float phase0 = frac(_Time.x * _TimeSpeed);
                float phase1 = frac(_Time.x * _TimeSpeed + 0.5);
                
                float3 flowTex0 = tex2D(_MainTex, i.uv - flowDir.xy * phase0); // uv - dir * time
                float3 flowTex1 = tex2D(_MainTex, i.uv - flowDir.xy * phase1);

                // Calculate weight
                float flowLerp = abs(0.5 - phase0) / 0.5;
                float3 finalColor = lerp(flowTex0, flowTex1, flowLerp);
                
                return fixed4(finalColor, 0.8);
            }
            ENDCG
        }
    }
}
