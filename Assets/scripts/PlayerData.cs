using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class PlayerData : MonoBehaviour
{
    public int level;
    public int maxLevel = 3;
    void Start(){                                //загрузка данных пользователя в начале игры
        level = PlayerPrefs.GetInt("level");
        if(level == 0){
            level = 1;
            PlayerPrefs.SetInt("level", level);
        }
    }
    public void SaveData(){                      //сохранить информацию пользователя(после того, как уровень пройден)
        PlayerPrefs.SetInt("level", level);
        Debug.Log(PlayerPrefs.GetInt("level"));
    }
    public void LoadData(){                     //на всякий случай загрузкка дынных пользователя
        level = (PlayerPrefs.GetInt("level"));
    }
    public void NextLevel(){                    //сохранение данных пользователя при переходе на след. уровень
        level = level + 1;
        SaveData();
        Debug.Log("level saved" + level);
    }
    public void ClearData(){                   //обнуление результата
        level = 1;
        PlayerPrefs.SetInt("level", level);
    }
}
