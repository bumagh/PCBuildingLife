using System;
using System.Collections.Generic;
using UnityEngine;
using Utf8Json;

public static partial class TableDataMgr
{
    public static event Func<string, byte[]> Event_OnGetTableData;

    #region Private Field

    private static CoreCompDataSet coreCompData;

    #endregion

    #region Public Method

    public static void LoadAllTableData()
    {
        CheckCoreCompTableData();

    }

    public static void UnloadAllTableData()
    {
        
    }

    public static CoreCompTableData GetSingleCoreCompTableData(int id)
    {
        CheckCoreCompTableData();
        return coreCompData.GetDataByID(id);
    }

    public static List<CoreCompTableData> GetAllCoreCompTableData()
    {
        CheckCoreCompTableData();
        return coreCompData.GetAllData();
    }

    #endregion

    #region Private Method

    private static void CheckCoreCompTableData()
    {
        if (coreCompData == null)
        {
            if (Event_OnGetTableData != null)
            {
                byte[] content = Event_OnGetTableData("CoreCompDataSet");
                List<CoreCompTableData> list = JsonSerializer.Deserialize<List<CoreCompTableData>>(content);
                if (list == null || list.Count <= 0)
                {
                    Debug.LogError("Json返序列化CoreCompDataSet.Json文件不成功");
                }
                coreCompData = new CoreCompDataSet();
                coreCompData.SetData(list);
            }
        }
    }

    #endregion
}
