using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class LevelNomber : MonoBehaviour
{

    public Text text;
    void Start()
    {
        text.text = text.text + SceneManager.GetActiveScene().buildIndex;

    }
}
