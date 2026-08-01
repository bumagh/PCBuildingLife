using System;

/// <summary>
/// 模拟服务器响应的模型
/// </summary>
[Serializable]
public class SimpleHttpResponse
{
    public int code;
    public string data;
    public string msg;
}
[Serializable]
public class HttpResponse<T>
{
    public int code;
    public T data;
    public string msg;
}