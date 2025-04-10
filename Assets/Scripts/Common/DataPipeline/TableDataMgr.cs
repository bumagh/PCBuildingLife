/**
* UnityVersion: 2019.3.15f1
* FileName:     TableDataMgr.cs
* Author:       TANYUQING
* CreateTime:   2020/09/08 14:11:35
* Description:
*/
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

/// <summary>
/// 客户端基础数据表管理类
/// 本类将与自动生成的TableDataMgr共同起作用，不可删除
/// </summary>
public static partial class TableDataMgr
{
    //存储表资源信息
    public static Dictionary<string, byte[]> tableAssetsDic = new Dictionary<string, byte[]>();

    static TableDataMgr()
    {
        //为解决utf8json在安卓上无法使用的问题，需要自定义解析器
        Utf8jsonHelper.RuntimeInitialize();

        Event_OnGetTableData += GetTableDataHandle;
    }

    /// <summary>
    /// 通过ID获取表文本   //已经国际化
    /// </summary>
    /// <returns></returns>
   
    /// <summary>
    /// 指明导出的表数据存储位置
    /// </summary>
    /// <param name="arg"></param>
    private static byte[] GetTableDataHandle(string arg)
    {
#if UNITY_EDITOR
        string tablePath = "Assets/ResourcesAddr/Table2Assets/" + arg + ".txt";
        TextAsset ta = UnityEditor.AssetDatabase.LoadAssetAtPath<TextAsset>(tablePath);
        Debug.Log(arg + " Len:" + ta.bytes.Length);
        //Debug.Log("load " + arg + "->" + ta.text);
        Debug.Log("load " + arg);
        return ta.bytes;
#else
        if (tableAssetsDic.Count == 0)
        {
            Debug.LogError($"表数据{arg}不存在,请检查");
            return null;
        }
        Debug.Log("load " + arg + " Len:" + tableAssetsDic[arg].Length);
        return tableAssetsDic[arg];
#endif
    }

    /// <summary>
    /// 获取当前系统语言，返回语言的简短表示如：en,zh
    /// </summary>
    /// <returns></returns>
    public static string GetCurrentLanguage()
    {
        SystemLanguage lang = Application.systemLanguage;
        string langStr = "";
        // //中文、简中、繁中 都返回中文文本，其它返回英文文本
        // if (
        //     lang == SystemLanguage.Chinese
        //     || lang == SystemLanguage.ChineseSimplified
        //     || lang == SystemLanguage.ChineseTraditional
        // )
        // {
        //     langStr = "zh";
        // }
        // else
        // {
        //     langStr = "en";
        // }

        // //测试方法1
        // //测试时，强制返回指定语言
        // //langStr = "en";
        // //langStr = "zh";
        // if (GameManager.instance == null)
        // {
        //     return langStr;
        // }
        // //测试方法2，由GameManager脚本控制：
        // SupportLanguage sl = GameManager.instance.language;

        // switch (sl)
        // {
        //     case SupportLanguage.Default:
        //         //Debug.Log("Default language.");
        //         break;
        //     case SupportLanguage.En:
        //         //Debug.Log("En language");
        //         langStr = "en";
        //         break;
        //     case SupportLanguage.Zh:
        //         //Debug.Log("Zh language");
        //         langStr = "zh";
        //         break;
        //     default:
        //         break;
        // }
        // //langStr = "en";
        // Debug.Log("当前系统语言:" + lang + ",简易表示：" + langStr);
        return langStr;
    }
}
