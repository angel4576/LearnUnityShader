# Learn Unity Shader
Collection of demos and study logs of my Unity Shader self-study  

**Unity Editor Version: 2022.3.43f1**  

## Dissolve
Dissolve effect based on noise texture
![Dissolve Picture](/Assets/Img/SimpleDissolve.png)

## Parallax Mapping
Steep Parallax Mapping and Parallax Occlusion Mapping
![Parallax Mapping1](/Assets/Img/parallaxMap1.png)
![Parallax Mapping2](/Assets/Img/parallaxMap2.png)

## Mask
Implements a sphere-based mask to create a world-switch effect. Incorporates Simplex noise and emission for a dynamic visual effect
![SphereMask](/Assets/Img/Mask.gif)

## Toon Shading
Explores stylized toon shading
- Left: Unity's built-in Standard Shader
- Right: A simplified two-tone approach
- middle: The final optimized toon shader for this demo

**Front View**
![Toon shading1](/Assets/Img/toon2.png)

**Back View**
![Toon shading2](/Assets/Img/toon1.png)

# Improved Outlines & lighting
Refines the white-model Toon Shading approach with:
- Optimized outlines to reduce breakage
- Smoother light/shadow transitions
- Added specular and rim lighting

![Toon Sphere](/Assets/Img/BetterToonSphere.png)
![White Yinlin Front](/Assets/Img/whiteYinlin.png)
![White Yinlin Back](/Assets/Img/whiteYinlinBack.png)

## Physically Based Rendering
Investigates the theory and implementation of Physically Based Rendering to achieve realistic lighting

- Left: Custom PBR Shader
- Right: Unity's Standard Shader

![PBR1](/Assets/Img/pbr1.png)
![PBR2](/Assets/Img/pbr2.png)
![PBR3](/Assets/Img/pbr4.png)
![PBR4](/Assets/Img/pbr3.png)

## Flow Map
Simple application of flow map
![Basic FlowMap](/Assets/Img/flowmap.gif)
