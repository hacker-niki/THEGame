using UnityEngine;
using UnityEngine.UI;
using System;

public class score : MonoBehaviour
{

    public Transform player;
    public Text text;

    // Update is called once per frame
    void Update()
    {
        text.text = (Math.Round(player.position.z / 10, 0)).ToString();
    }
}
