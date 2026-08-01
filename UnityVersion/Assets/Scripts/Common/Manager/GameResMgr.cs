/**
* UnityVersion: 2019.3.15f1
* FileName:     GameResMgr.cs
* Author:       TANYUQING
* CreateTime:   2020/09/12 17:50:17
* Description:  
*/
using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.AddressableAssets.ResourceLocators;
using UnityEngine.ResourceManagement.AsyncOperations;

/// <summary>
/// 处理整个游戏的资源加载
/// </summary>
[DefaultExecutionOrder(-10000)]
public class GameResMgr : MonoBehaviour
{
    public static GameResMgr instance = null;

    /// <summary>
    /// 资源是否加载完成
    /// </summary>
    public bool IsResLoadComplete { get => isResLoadComplete;}
    private bool isResLoadComplete = false;

    void Awake()
    {
        #region 确保ModelMgr一直存在，且唯一
        if (GameResMgr.instance != null)
        {
            Destroy(gameObject);
            return;
        }
        instance = this;
        DontDestroyOnLoad(gameObject);
        #endregion

        Init();
    }

    private void Init()
    {
        isResLoadComplete = false;

        //加载基础数据表
        LoadBasicTableData();
    }

    /// <summary>
    /// 加载数据表
    /// </summary>
    async private void LoadBasicTableData ()
    {
        //数据表在addreddable系统中的标签
        string label = "default";

        AsyncOperationHandle<IList<TextAsset>> handle = Addressables.LoadAssetsAsync<TextAsset>(label, null);

        await handle.Task;
        if (handle.Status == AsyncOperationStatus.Succeeded)
        {
            Dictionary<string, byte[]> dic = new Dictionary<string, byte[]>();
            Debug.Log("Loading Table..");
            for (int i = 0; i < handle.Result.Count; i++)
            {
                dic.Add(handle.Result[i].name, handle.Result[i].bytes);
                Debug.Log($"{i} [{handle.Result[i].name}] -> {handle.Result[i].text}");
                Debug.Log($"{i} [{handle.Result[i].name}]");
            }

            TableDataMgr.tableAssetsDic = dic;
            Debug.Log("加载数据表成功！数量：" + dic.Count);
            isResLoadComplete = true;
        } 
        else
        {
            Debug.LogError("加载数据表失败, label:" + label);
        }
    }

    /// <summary>
    /// 等待资源加载完成，然后返回
    /// </summary>
    /// <returns></returns>
    async public Task WaitForResLoadComplete ()
    {
        while (!IsResLoadComplete)
        {
            await Task.Delay(100);

            // if (IsResLoadComplete)
            // {
            //     //初始化数据表
            //     Utils.ColorLog(LogColor.red, $"执行 InitTable", true);
            //     ModelMgr.instance.InitTable();

            //     Utils.ColorLog(LogColor.red, $"执行 LoadDataForLocalCache", true);
            //     ModelMgr.instance.LoadDataForLocalCache();
            //     return;
            // }
        }
    }
}
