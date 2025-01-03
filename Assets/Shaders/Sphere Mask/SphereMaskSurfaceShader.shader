Shader "Custom/SphereMaskSurfShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        
        _RevealInSphere("Reveal Object in sphere", Range(0,1)) = 0
        _EdgeWidth ("Edge Width", Range(0, 1)) = 0.1

        [HDR]_Emission("Emission", Color) = (1,1,1,1)
        // _NoiseSize("Noise Size", float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull off
        LOD 200

        CGPROGRAM
        // Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
        // #pragma exclude_renderers d3d11 gles
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        #include "../../ShaderLibrary/noiseSimplex.cginc"

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
            float3 worldPos;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        // Spherical Mask
        float4 _Position;
        half _Radius;
        half _Softness;
        half _RevealInSphere;

        // Emission
        fixed4 _Emission;
        float _NoiseSize;
        half _EdgeWidth;

        // Simplex Noise Control
        float _NoiseFrequency;
        float _NoiseOffset;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
        // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)


        // Simple random noise 
        float random (float2 input) { 
            return frac(sin(dot(input, float2(12.9898,78.233)))* 43758.5453123);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

            // Grayscale
            // half grayscale = (c.r + c.g + c.b) * 0.333; // divide is slower than multiplicaitons
            // fixed3 c_grayscale = fixed3(grayscale, grayscale, grayscale);

            // Noise
            float noiseValue = random(IN.uv_MainTex * _NoiseSize) * 0.5;
            float simplexNoise = snoise(IN.worldPos) * _NoiseFrequency + _NoiseOffset;
            
            half d = distance(_Position, IN.worldPos) + simplexNoise;
            half sum = saturate((d - _Radius) / _Softness); // clamp to 0-1 (dist between pos and circle ring)
            
            if(_RevealInSphere > 0.5f)
            {
                sum = 1 - saturate((d - _Radius) / _Softness); 
            }

            // fixed4 lerpColor = lerp(fixed4(c_grayscale, 1), c, sum);
            clip(sum - 0.01);
           
            // Emission Noise
            float squares = step(0.5, random(floor(IN.uv_MainTex * _NoiseSize)));
            half emissionRing = step(sum - 0.01, _EdgeWidth) * squares;

            o.Albedo = c.rgb;
            o.Emission = _Emission * emissionRing;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
