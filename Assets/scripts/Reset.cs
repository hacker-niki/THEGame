using UnityEngine;
using UnityEngine.SceneManagement;

public class Reset : MonoBehaviour
{
    public PlayerData PlayerData;
    public void ResetProgress(){
        PlayerData.ClearData();
        Debug.Log("Reset!");
        SceneManager.LoadScene("StartMenu");
    }
}
