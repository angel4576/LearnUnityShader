using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SmoothNormal : MonoBehaviour
{
    private SkinnedMeshRenderer meshRenderer;
    private void Awake() 
    {
        meshRenderer = GetComponent<SkinnedMeshRenderer>();
        Mesh body = meshRenderer.sharedMesh;
        if(body)
        {
            
            Debug.Log("Get Mesh");
        }
        else
        {
            Debug.Log("Cannnot get mesh");
        }
    }
    Mesh MeshNormalAverage(Mesh mesh)
    {
        return mesh;
    }   
    
}
