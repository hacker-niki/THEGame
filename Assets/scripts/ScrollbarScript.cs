using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class ScrollbarScript : MonoBehaviour
{
    public PlayerData PlayerData;
    void Start() {
        GetComponent<Scrollbar>().value = PlayerData.difficalty;  
    }
    public void SaveScroll(){
        PlayerData.difficalty = GetComponent<Scrollbar>().value;
        PlayerData.SaveData();
    }
}
