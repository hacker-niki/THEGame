using UnityEngine;
using System;

public class follow : MonoBehaviour
{
    public playermovement movement;
    public Transform Player;
    public Vector3 Vector3;
    public bool CameraStartMovement;
    public int CameraStartSpeed;
    bool gameStarts = false;
    void Start()
    {
        movement.enabled = false;
    }
    // Update is called once per frame
    void FixedUpdate()
    {
        if (Math.Round(Player.transform.position.z, 0) == Math.Round(transform.position.z-Vector3.z, 0))
        {
            if (gameStarts == false)
            {
                CameraStartMovement = false;
                movement.enabled = true;
                gameStarts = true;
            }
        }
        if (CameraStartMovement == true)
        {
            transform.position += Vector3.forward*Time.deltaTime* CameraStartSpeed;
        }
       else
            transform.position = Player.position + Vector3;
    }
}
