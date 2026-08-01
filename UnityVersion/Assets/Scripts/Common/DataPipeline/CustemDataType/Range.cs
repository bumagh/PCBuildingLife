/**
* UnityVersion: 2019.3.15f1
* FileName:     Range.cs
* Author:       TANYUQING
* CreateTime:   2020/09/07 10:51:39
* Description:  
*/
using System;

/// <summary>
/// 数据生产线自定义类型：范围
/// </summary>
[Serializable]
public class Range
{
    /// <summary>
    /// 最小值
    /// </summary>
    public float min;
    /// <summary>
    /// 最大值
    /// </summary>
    public float max;

    public override string ToString()
    {
        return string.Format("[min:{0},max:{1}]", min, max);
    }
}
