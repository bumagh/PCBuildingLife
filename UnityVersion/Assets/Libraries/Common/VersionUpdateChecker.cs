using UnityEngine;
using UnityEngine.Networking;
using System.Collections;
using UnityEngine.UI;
using System;

public class VersionUpdateChecker : MonoBehaviour
{
    // 当前的版本号，可以通过在 Player Settings 中设置版本号来获取
    private string currentVersion;
    private Coroutine downloadCoroutine;
    public Text versionText; // 显示当前版本号
    public Text updateMessage; // 显示更新信息
    public static VersionUpdateChecker instance;
    public UpdateInfoResp updateInfoResp;
    void Awake()
    {
        instance = this;
        currentVersion = Application.version;  // 获取当前应用的版本
        versionText.text = "当前版本: " + currentVersion;
        StartCoroutine(CheckForUpdate());
    }

    /// <summary>
    /// 检查服务器是否有新版本
    /// </summary>
    public IEnumerator CheckForUpdate()
    {
        string serverUrl = HttpService<string>.HTTP_URL + "v1.version/index?limit=10";  // 替换为你自己的版本检测接口

        using (UnityWebRequest webRequest = UnityWebRequest.Get(serverUrl))
        {
            // 发送请求到服务器
            yield return webRequest.SendWebRequest();

            if (webRequest.result == UnityWebRequest.Result.ConnectionError || webRequest.result == UnityWebRequest.Result.ProtocolError)
            {
                Debug.LogError("Error checking version: " + webRequest.error);
            }
            else
            {
                // 解析服务器返回的数据
                string jsonResponse = webRequest.downloadHandler.text;
                UpdateInfoResp updateInfo = JsonUtility.FromJson<UpdateInfoResp>(jsonResponse);
                updateInfoResp = updateInfo;
                string serverVersion = updateInfo.data[0].version;
                string serverDesc = updateInfo.data[0].description;
                string serverapkurl = updateInfo.data[0].apkurl;
                Debug.Log("Server version: " + serverVersion);
                Debug.Log("Cur version: " + currentVersion);
                bool needUpdate = IsNewVersionAvailable(currentVersion, serverVersion);
                EventManager.DispatchEvent<bool>(EventName.LoginSetIsLatestVersion, !needUpdate);
                // 比较服务器版本和本地版本
                if (needUpdate)
                {
                    // 如果有新版本，提示用户并提供更新链接
                    updateMessage.text = "有新版本更新! \n" + serverDesc;
                    // if (Application.platform != RuntimePlatform.Android || Tools.isDebug) yield break;
                    string filePath = System.IO.Path.Combine(Application.persistentDataPath, "game_" + serverVersion + ".apk");
                    if (System.IO.File.Exists(filePath))
                    {
                        Debug.Log("APK already downloaded: " + filePath);
                        TextDialog.ShowConfirm("版本更新", "已经下载过此版本,是否立即更新?", () =>
                        {
                            bool installRes = Install(filePath);
                            TextTip.Show(installRes ? "启动安装成功" : "启动安装失败");
                        });
                        yield break;
                    }
                    TextDialog.ShowConfirm("版本更新", "当前版本过低,请点击确定立即更新!", () =>
                    {
                        downloadCoroutine = StartCoroutine(DownloadAndInstallAPK(serverapkurl, serverVersion));
                        VersionUpdateDialog.Show("正在下载更新，请稍候...", () =>
                        {
                            StopCoroutine(downloadCoroutine);
                        });

                    });

                }
                else
                {
                    updateMessage.text = "不需要更新.";
                    TextTip.Show("不需要更新");
                }
            }
        }
    }

    /// <summary>
    /// 比较两个版本号
    /// </summary>
    private bool IsNewVersionAvailable(string currentVersion, string serverVersion)
    {
        Version current = new Version(currentVersion);
        Version server = new Version(serverVersion);

        return server.CompareTo(current) > 0;  // 如果服务器版本大于当前版本，返回 true
    }

    /// <summary>
    /// 下载 APK 并提示用户安装
    /// </summary>
    private IEnumerator DownloadAndInstallAPK(string apkUrl, string apkVersion)
    {

        using (UnityWebRequest webRequest = UnityWebRequest.Get(apkUrl))
        {
            // 忽略 SSL 证书验证
            webRequest.certificateHandler = new IgnoreCertificateHandler();
            // 显示下载进度
            float downloadProgress = 0f;
            // 下载 APK 文件
            webRequest.SendWebRequest();
            while (!webRequest.isDone)
            {
                // 更新下载进度
                downloadProgress = webRequest.downloadProgress * 100;
                Debug.Log($"Downloading: {downloadProgress}%");
                VersionUpdateDialog.UpdateProgress(downloadProgress);
                // 更新UI显示下载进度（如果有进度条）
                // 这里你可以更新一个进度条或文本
                yield return null;
            }
            if (webRequest.result == UnityWebRequest.Result.ConnectionError || webRequest.result == UnityWebRequest.Result.ProtocolError)
            {
                Debug.LogError("Error downloading APK: " + webRequest.error);
            }
            else
            {
                // 将下载的 APK 保存到本地
                string filePath = System.IO.Path.Combine(Application.persistentDataPath, "game_" + apkVersion + ".apk");
                System.IO.File.WriteAllBytes(filePath, webRequest.downloadHandler.data);
                Debug.Log("APK downloaded to: " + filePath);
                // Tools.ShowTip("下载更新完成");
                //TODO:检测是否已经有缓存下载过避免重复下载同一版本
                TextTip.Show("下载更新完成，正在启动安装...", 1.5f, () =>
                {
                    Install(filePath);
                });
            }
        }
    }
    public bool Install(string apkPath)
    {
        Debug.Log("call android Install");
        AndroidJavaClass javaClass = new AndroidJavaClass("com.example.mylibrary.Install");
        return javaClass.CallStatic<bool>("InstallApk", apkPath);
    }
    public class IgnoreCertificateHandler : CertificateHandler
    {
        // 重写验证方法，始终返回 true，忽略 SSL 验证
        protected override bool ValidateCertificate(byte[] certificateData)
        {
            return true;
        }
    }
    /// <summary>
    /// 用于解析服务器返回的版本信息
    /// </summary>

}
[Serializable]
public class UpdateInfoResp
{
    public int code;
    public string msg;
    public UpdateInfo[] data;
}

[Serializable]
public class UpdateInfo
{
    public string version;
    public string apkurl;
    public string description;
}