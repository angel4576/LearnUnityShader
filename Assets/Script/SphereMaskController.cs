using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class SphereMaskController : MonoBehaviour
{
    public float radius = 0.2f;
    public float maxRadius;
    public float minRadius;
    public float speed;
    public float softness;
    public float noiseSize;
    [Range(0, 1.0f)]
    public float noiseFrequency;
    public float noiseOffset;

    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        Shader.SetGlobalFloat("_Radius", radius);
        Shader.SetGlobalFloat("_Softness", softness);
        Shader.SetGlobalVector("_Position", transform.position);
        Shader.SetGlobalFloat("_NoiseSize", noiseSize);

        // Noise
        Shader.SetGlobalFloat("_NoiseFrequency", noiseFrequency);
        Shader.SetGlobalFloat("_NoiseOffset", noiseOffset);

        radius += speed * Time.deltaTime;
          
        if(radius > maxRadius)
        {
            radius = maxRadius;
            speed = -speed;
        }

        else if(radius < minRadius)
        {
            radius = minRadius;
            speed = -speed;
        }
    }
}
