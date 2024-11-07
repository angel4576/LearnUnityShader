using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class DissolveController : MonoBehaviour
{
    [Range(0, 1)]
    public float threshold;
    public float changeSpeed;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Shader.SetGlobalFloat("_DissolveThreshold", threshold);

        //threshold -= changeSpeed * Time.deltaTime;
        if(threshold <= 0.001f)
        {
            StartCoroutine(CoolDown());
            // threshold = 0;
        }
    }

    IEnumerator CoolDown()
    {
        yield return new WaitForSeconds(1.0f);
        threshold = 1;
    }
}
