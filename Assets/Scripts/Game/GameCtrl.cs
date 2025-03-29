
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class GameCtrl : MonoBehaviour
{
    private Button menuBtn;


    void Awake()
    {

        menuBtn = transform.Find("MenuBtn").GetComponent<Button>();

        menuBtn.onClick.AddListener(() =>
        {

        });

    }



    async void Start()
    {

    }
    void OnDestroy()
    {
    }
}