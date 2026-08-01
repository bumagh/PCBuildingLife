
using System;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class LoginController : MonoBehaviour
{
    private Button startBtn;
    private Button exitBtn;
    private bool isLatestVersion = false;
    void Awake()
    {
        
        EventManager.AddEvent<bool>(EventName.LoginSetIsLatestVersion, this.LoginSetIsLatestVersion);
        startBtn = GameObject.Find("Canvas/StartBtn").GetComponent<Button>();
        exitBtn = GameObject.Find("Canvas/ExitBtn").GetComponent<Button>();
        startBtn.onClick.AddListener(() =>
        {
            if (isLatestVersion)
               SceneManager.LoadScene("Game");
            else
            {
                StartCoroutine(VersionUpdateChecker.instance.CheckForUpdate());
                // Tools.ShowConfirm("当前版本过低,请先更新,是否立即检测更新");
            }
        });

        exitBtn.onClick.AddListener(() =>
       {
           TextDialog.ShowConfirm("退出确认","确认要退出游戏吗?", () =>
           {
               Application.Quit();
           });
       });
    }

    private void LoginSetIsLatestVersion(bool isLatestVersion)
    {
        this.isLatestVersion = isLatestVersion;
    }

    async void Start()
    {
       
    }
    void OnDestroy()
    {
        EventManager.RemoveEvent<bool>(EventName.LoginSetIsLatestVersion, this.LoginSetIsLatestVersion);
    }
}