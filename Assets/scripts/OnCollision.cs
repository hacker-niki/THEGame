using UnityEngine;

public class OnCollision : MonoBehaviour
{
    public playermovement movement;
    public follow follow;
    void OnCollisionEnter(Collision collision)
    {
       if(collision.collider.tag == "box")
        {
            follow.enabled = false;
            movement.enabled = false;
            FindObjectOfType<GameManager>().EndGame();
        }
    }
}
