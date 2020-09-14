using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SendMatrix : MonoBehaviour
{
    Matrix4x4 previousModelMatrix;
    Matrix4x4 currentModelMatrix;
    public Material material;

    void Start()
    {
        currentModelMatrix = transform.localToWorldMatrix;
        previousModelMatrix = currentModelMatrix;
    }
    void FixedUpdate()
    {
        Renderer rend = GetComponent<Renderer>();
        previousModelMatrix = currentModelMatrix;
        currentModelMatrix = transform.localToWorldMatrix;
        
        material.SetMatrix("_PreviousFrameModelMatrix", previousModelMatrix);
        material.SetMatrix("_CurrentFrameInverseModelMatrix", currentModelMatrix.inverse);
        material.SetMatrix("_CurrentFrameModelMatrix", currentModelMatrix);
        Debug.Log(previousModelMatrix);
    }
}
