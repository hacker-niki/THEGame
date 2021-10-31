using UnityEngine;
using UnityEngine.SceneManagement;

public class reserve : MonoBehaviour
{
    public PlayerData PlayerData;
    public void LentsGo()
    {
        Debug.Log("START");
        SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex + PlayerData.level);            //загрузка сцены в соостветствии с последним сохраненным уровнм
        Debug.Log(PlayerData.level);
    }
}
