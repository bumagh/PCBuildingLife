/**
* UnityVersion: 2019.3.15f1
* FileName:     MenuItemMgr.cs
* Author:       TANYUQING
* CreateTime:   2020/09/16 12:25:05
* Description:  
*/
#if UNITY_EDITOR
using System;
using System.Diagnostics;
using System.IO;
using UnityEditor;
using UnityEngine;
using Debug = UnityEngine.Debug;

/// <summary>
/// 自定义unity菜单管理
/// </summary>
public class MenuItemMgr : MonoBehaviour
{
    [UnityEditor.MenuItem("Tools/清除全部本地数据")]
    /// <summary>
    /// 清除本地数据
    /// </summary>
    public static void DeleteAllLocalData()
    {
        PlayerPrefs.DeleteAll();
        Debug.Log("All PlayerPrefs data has been deleted.");
    }

    [UnityEditor.MenuItem("Tools/清除本地引导进度数据")]
    /// <summary>
    /// 清除引导进度数据
    /// </summary>
    public static void DeleteGuideProgressData()
    {
        PlayerPrefs.DeleteKey(LocalData.guideProgressKey);
        Debug.Log("Guide progress data has been deleted.");
    }
    [UnityEditor.MenuItem("Tools/将引导进度置为2阶段开始")]
    /// <summary>
    /// 清除引导进度数据
    /// </summary>
    public static void SetGuideProgressToPart2()
    {
        PlayerPrefs.SetInt(LocalData.guideProgressKey, 6);
        Debug.Log("Guide progress has been set to 6");
    }

    [MenuItem("Tools/3.生成JsonFormater脚本(utf8json)--导入表格数据后使用", false, 3)]
    private static void GenerateJsonFormatter()
    {
        string exePath = Path.GetFullPath(".");
        exePath = Path.Combine(exePath, "../../../tool/Utf8Json.UniversalCodeGenerator/win-x64/Utf8Json.UniversalCodeGenerator.exe");
        exePath = Path.GetFullPath(exePath);
        string sourcePath_1 = Path.GetFullPath(Path.Combine(Application.dataPath, "Scripts/Table2CS"));
        string sourcePath_2 = Path.GetFullPath(Path.Combine(Application.dataPath, "Scripts/Common/DataPipeline/CustemDataType"));
        //string sourcePath_3 = Path.GetFullPath(Path.Combine(Application.dataPath, "Scripts/Game/Utf8JsonSourceFile"));
        string outputPath = Path.GetFullPath(Path.Combine(Application.dataPath, "Scripts/Common/DataPipeline/GeneratedResolver.cs"));

        //string param0 = $"-d {sourcePath_1},{sourcePath_2},{sourcePath_3}";
        string param0 = $"-d {sourcePath_1},{sourcePath_2}";
        string param1 = $"-o {outputPath}";
        string argument = $"{param0} {param1}";
        Debug.Log(exePath);
        Debug.Log(argument);
        try
        {
            using (Process process = new Process())
            {
                process.StartInfo.WindowStyle = ProcessWindowStyle.Normal;
                process.StartInfo.FileName = exePath;
                process.StartInfo.Arguments = argument;
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.RedirectStandardOutput = true;
                process.Start();
                process.WaitForExit();
                Debug.Log(process.StandardOutput.ReadToEnd());
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"生成反序列化脚本出现异常：{e}");
        }
    }
}
#endif