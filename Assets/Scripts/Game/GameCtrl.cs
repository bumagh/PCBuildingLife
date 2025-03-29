
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class GameCtrl : MonoBehaviour
{
    private Button menuBtn;
    private Button caseBtn;

    void Awake()
    {

        menuBtn = transform.Find("MenuBtn").GetComponent<Button>();
        caseBtn = transform.Find("Panel/Building/Case (1)").GetComponent<Button>();
        caseBtn.onClick.AddListener(() =>
      {
        Debug.Log("clicked");
      });
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