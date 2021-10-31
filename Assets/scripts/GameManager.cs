using UnityEngine;
using UnityEngine.SceneManagement;

public class GameManager : MonoBehaviour
{
    bool gameHasEnded = false;
    public float restartDelay = 2f;
    public playermovement movement;
    public GameObject completeLevelUI;
    public PlayerData PlayerData;
    public void CompleteLevel()
    {
        Debug.Log("LEVEL WON!");
        PlayerData.NextLevel();
        completeLevelUI.SetActive(true);
        movement.enabled = false;
    }
    public void EndGame()
    {
        if(gameHasEnded == false)
        {
            gameHasEnded = true;
            Debug.Log("GAME OVER");
            Invoke("Restart", restartDelay);
        }
    }
    void Restart()
    {
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }
}
