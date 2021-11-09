using UnityEngine;

public class playermovement : MonoBehaviour
{

    public PlayerData playerData;
    public Rigidbody rb;
    public float diff;
    public float speed_b = 600f;
    float force;
    // Update is called once per frame
    void FixedUpdate()
    {
        force = playerData.forward;
        rb.AddForce(0, 0, force * Time.deltaTime);
        
        if (Input.GetKey("a"))
        {
            rb.AddForce(-speed_b * Time.deltaTime, 0, 0, ForceMode.VelocityChange);
        }

        if (Input.GetKey("d"))
        {
            rb.AddForce(speed_b * Time.deltaTime, 0, 0, ForceMode.VelocityChange);
        }
        
        if(rb.transform.position.y < 0)
        {
            FindObjectOfType<GameManager>().EndGame();
        }
    }
}
