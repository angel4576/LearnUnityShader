using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEditor;
using UnityEngine;

public class SmoothNormalsTool
{
    [MenuItem("Tools/Smooth Normals")]
    public static void WriteAverageNormalsToTangent()
    {
        MeshFilter[] meshFilters = Selection.activeGameObject.GetComponentsInChildren<MeshFilter>();
        foreach (var meshFilter in meshFilters)
        {
            Mesh mesh = meshFilter.sharedMesh;
            WriteAverageNormalToTangent(mesh);
            // Debug.Log("Tool");
        }


        SkinnedMeshRenderer[] skinnedMeshRenderers = Selection.activeGameObject.GetComponentsInChildren<SkinnedMeshRenderer>();
        foreach (var skinMeshRenderer in skinnedMeshRenderers)
        {
            Mesh mesh = skinMeshRenderer.sharedMesh;
            WriteAverageNormalToTangent(mesh);
        }

    }

    private static void WriteAverageNormalToTangent(Mesh mesh)
    {
        var averageNormalTable = new Dictionary<Vector3, Vector3>();
        for (int i = 0; i < mesh.vertexCount; i++)
        {
            if(!averageNormalTable.ContainsKey(mesh.vertices[i]))
            {
                averageNormalTable.Add(mesh.vertices[i], mesh.normals[i]); // add vertex normals if table does not contain
            }
            else
            {
                // 如果对于当前顶点有对应的多条法线，进行平均操作（加起来并归一化）
                averageNormalTable[mesh.vertices[i]] = (averageNormalTable[mesh.vertices[i]] + mesh.normals[i]).normalized;
            }
        }

        Vector3[] averageNormals = new Vector3[mesh.vertexCount];
        for (int i = 0; i < mesh.vertexCount; i++)
        {
            averageNormals[i] = averageNormalTable[mesh.vertices[i]];
        }

        // write into model normal data
        mesh.normals = averageNormals;
        
    }
   
}
