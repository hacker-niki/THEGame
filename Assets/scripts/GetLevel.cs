using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class GetLevel : MonoBehaviour
{
    public PlayerData PlayerData;
    // Start is called before the first frame update
    void Start()
    {
        PlayerData.LoadData(); //загрузка данных в PlayerData
        GetComponent<Text>().text = "Last saved level: " + PlayerData.level;        
    }
    
}
