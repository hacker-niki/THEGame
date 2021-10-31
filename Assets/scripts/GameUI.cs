using UnityEngine;

public class GameUI : MonoBehaviour
{
    public GameObject Menu;
    public playermovement movement;
    public void MenuOn()
    {
        Menu.SetActive(true);
        movement.enabled = false;
    }
    public void MenuOff()
    {
        Menu.SetActive(false);
        movement.enabled = true;
    }
}
