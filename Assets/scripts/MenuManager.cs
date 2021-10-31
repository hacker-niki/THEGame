using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class MenuManager : MonoBehaviour
{
    public PlayerData PlayerData;
    public int NumberStartLevel;
    public Button lvl1;
    public Button lvl2;
    public Button lvl3;
    public Button lvl4;
    public Button lvl5;

    void Start() {
        if(PlayerData.level == 1){
            lvl2.interactable = false;
            lvl3.interactable = false;
            lvl4.interactable = false;
            lvl5.interactable = false;
        }
        if(PlayerData.level == 2){
            lvl3.interactable  = false;
            lvl4.interactable = false;
            lvl5.interactable = false;
        }
        if(PlayerData.level == 3){
            lvl4.interactable = false;
            lvl5.interactable = false;
        }
        if(PlayerData.level == 4){
            lvl5.interactable = false;
        }
    }
    public void StartLevel1(){
        SceneManager.LoadScene(1);
    }
    public void StartLevel2(){
        SceneManager.LoadScene(2);
    }
    public void StartLevel3(){
        SceneManager.LoadScene(3);
    }
    public void StartLevel4(){
        SceneManager.LoadScene(4);
    }
    public void StartLevel5(){
        SceneManager.LoadScene(5);
    }
}
