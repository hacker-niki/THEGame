using UnityEngine;
using UnityEngine.SceneManagement;

public class Start : MonoBehaviour
{
    public PlayerData PlayerData;
    public GameObject Menu;
    public GameObject SettingsList;
    public void LentsGo()
    {
        Debug.Log("START");
        if(PlayerData.level > SceneManager.sceneCountInBuildSettings){
            PlayerData.ClearData();
            SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex + PlayerData.level);
        }
        else{
            SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex + PlayerData.level);            //загрузка сцены в соостветствии с последним сохраненным уровнм
            Debug.Log(PlayerData.level);
        }
    }
    public void Out()
    {
                Debug.Log("Exit!!!");

        Application.Quit();
    }
    public void MenuOn()
    {
        Menu.SetActive(true);
    }
    public void SettingsOn()
    {
        SettingsList.SetActive(true);
    }
    public void MenuOff()
    {
        Menu.SetActive(false);
    }
    public void SettingsOff()
    {
        SettingsList.SetActive(false);
    }
}
