using UnityEngine;

public class playermovement : MonoBehaviour
{

    public Rigidbody rb;
    public float speed_w = 1000f; //speed
    public float speed_b = 600f;

    // Update is called once per frame
    void FixedUpdate()
    {
        rb.AddForce(0, 0, speed_w * Time.deltaTime);
        
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
