using System;
using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

public class HttpService<T>
{
    #region HTTP相关的接口定义
    public static string HTTP_URL =Tools.isDebug ? "http://pcblapi/api/" : "https://api.tutlab.tech/api/";
    #endregion

    private static void SetHttpHeaders(UnityWebRequest webRequest, string extraHeader = "")
    {
        webRequest.SetRequestHeader("Content-Type", "application/json");
        webRequest.SetRequestHeader("Accept", "*/*");
        if (extraHeader != "")
        {
            webRequest.SetRequestHeader("token", extraHeader);
        }
    }

    public static IEnumerator DoGet(string sendUrl, Action<HttpResponse<T>> getCallback, string token = "")
    {
        UnityWebRequest webRequest = UnityWebRequest.Get(HTTP_URL + sendUrl);
        Debug.Log($"正在发送请求: {HTTP_URL + sendUrl}");  // 打印请求 URL
        SetHttpHeaders(webRequest, token);
        yield return webRequest.SendWebRequest();

        if (webRequest.result == UnityWebRequest.Result.ConnectionError || webRequest.result == UnityWebRequest.Result.ProtocolError)
        {
            Debug.LogError($"网络错误: {webRequest.error}");
            Debug.LogError($"响应码: {webRequest.responseCode}");
        }
        else
        {
            try
            {
                // 解析返回的 JSON 数据
                string responseJson = webRequest.downloadHandler.text;
                // 解析响应中的消息和状态
                HttpResponse<T> httpResponse = JsonUtility.FromJson<HttpResponse<T>>(responseJson);
                if (httpResponse.data != null)
                    Debug.Log(httpResponse.data.ToString());
                // 处理响应
                // if (ParseHttpResponseHeader(httpResponse))
                // {
                //     Debug.LogError($"返回的内容: {webRequest.downloadHandler.text}");
                getCallback?.Invoke(httpResponse);
                // }
            }
            catch (Exception ex)
            {
                Debug.LogError("DoGet错误: " + ex.Message);
            }
        }
    }
    /// <summary>
    /// POST请求接口
    /// </summary>
    /// <param name="_postData">实体类转换的Json字符串</param>
    /// <param name="callbackHandler">回调函数</param>
    /// <returns></returns>
    public static IEnumerator DOPostData(string sendUrl, string _postData = "{}", Action<HttpResponse<T>> postCallback = null, string extraHeader = "")
    {
        Debug.Log($"发送的数据: {_postData}");
        using (UnityWebRequest webRequest = UnityWebRequest.Put(HTTP_URL + sendUrl, System.Text.Encoding.UTF8.GetBytes(_postData)))
        {
            webRequest.method = "POST";
            webRequest.downloadHandler = new DownloadHandlerBuffer();
            SetHttpHeaders(webRequest, extraHeader);

            yield return webRequest.SendWebRequest();

            if (webRequest.result == UnityWebRequest.Result.ConnectionError || webRequest.result == UnityWebRequest.Result.ProtocolError)
            {
                // Tools.ShowTip("网络问题:" + webRequest.error);
            }
            else
            {
                try
                {
                    // 解析返回的 JSON 数据
                    string responseJson = webRequest.downloadHandler.text;
                    Debug.Log("服务器返回的 JSON 数据: " + responseJson);
                    HttpResponse<T> httpResponse = JsonUtility.FromJson<HttpResponse<T>>(responseJson);
                    postCallback?.Invoke(httpResponse);
                }
                catch (Exception ex)
                {
                    Debug.LogError("DOPostData: " + ex.Message);
                }
            }
        }
    }
  

}


