using System.Collections.Generic;
using UnityEngine;

public class CoreCompDataSet
{
    private List<CoreCompTableData> tempList;
    private List<CoreCompTableData> dataList;
    private Dictionary<int, CoreCompTableData> dataDic;

    public void SetData(List<CoreCompTableData> list)
    {
        if (dataList == null)
        {
            dataList = new List<CoreCompTableData>();
        }
        if (dataDic == null)
        {
            dataDic = new Dictionary<int, CoreCompTableData>();
        }
        dataList.Clear();
        dataDic.Clear();
        foreach (CoreCompTableData item in list)
        {
            dataList.Add(item);
            if (dataDic.ContainsKey(item.id))
            {
                Debug.LogError(string.Format("{0}表中Id{1}重复", "CoreCompTableData", item.id));
            }
            else
            {
                dataDic.Add(item.id, item);
            }
        }
    }

    public List<CoreCompTableData> GetAllData()
    {
        if (tempList == null)
        {
            tempList = new List<CoreCompTableData>();
        }
        tempList.Clear();
        tempList.AddRange(dataList);
        return tempList;
    }

    public CoreCompTableData GetDataByID(int id)
    {
        if (dataDic.ContainsKey(id))
        {
            return dataDic[id];
        }
        else
        {
            Debug.LogError(string.Format("{0}中数据表中不包含此ID{1}", "CoreCompTableData", id));
            return null;
        }
    }
}