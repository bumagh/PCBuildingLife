/**
* UnityVersion: 2019.3.15f1
* FileName:     LocalData.cs
* Author:       LT-19
* CreateTime:   2021/02/02 16:23:00
* Description:  
*/
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 客户端本地用PlayerPrefs存储的数据
/// </summary>
public class LocalData
{
    /// <summary>
    /// 引导进入存储key: "GuideProgress"
    /// </summary>
    public const string guideProgressKey = "GuideProgress";

    /// <summary>
    /// 冒险币
    /// </summary>
    private static int riskCoin;
    /// <summary>
    /// 冒险币
    /// </summary>
    public static int RiskCoin
    {
        get
        {
            riskCoin = PlayerPrefs.GetInt("RiskCoin", 0);
            return riskCoin;
        }
        set
        {
            riskCoin = value;
            PlayerPrefs.SetInt("RiskCoin", riskCoin);
        }
    }

    /// <summary>
    /// 引导第1阶段结束标识(如果引导进度为此值，则表示第1阶段完成)
    /// 引导第1阶段指的是打完引导关卡（共2关）
    /// </summary>
    public const int guideSg1FinishMark = 6;

    /// <summary>
    /// 引导总进度结束标识(如果引导进度为此值，则表示引导完成)
    /// </summary>
    public const int guideFinishMark = 17;

    //新手引导进度
    private static int guidePogress;
    /// <summary>
    /// 新手引导进度，0为未开始，1表示引导1已完成，2表示引导2已完成， 后续类推
    /// </summary>
    public static int GuidePogress
    {
        get {
            guidePogress = PlayerPrefs.GetInt(guideProgressKey, 0);
            return guidePogress;
        }
        set
        {
            guidePogress = value;
            PlayerPrefs.SetInt(guideProgressKey, guidePogress);
        }
    }


    private static int isJumpPVE;
    /// <summary>
    /// 是否从pvp跳转 0:否  1：是
    /// </summary>
    public static int IsJumpPVE
    {
        get
        {
            isJumpPVE = PlayerPrefs.GetInt("IsJumpPVE", 0);
            return isJumpPVE;
        }
        set
        {
            isJumpPVE = value;
            PlayerPrefs.SetInt("IsJumpPVE", isJumpPVE);
        }
    }


    private static int getBoxIndex;
    /// <summary>
    /// 是获得宝箱 0,1,2,3获得  -1未获得
    /// </summary>
    public static int GetBoxIndex
    {
        get
        {
            getBoxIndex = PlayerPrefs.GetInt("GetBoxIndex", -1);
            return getBoxIndex;
        }
        set
        {
            getBoxIndex = value;
            PlayerPrefs.SetInt("GetBoxIndex", getBoxIndex);
        }
    }
    /// <summary>
    /// 奖杯变化数
    /// </summary>
    public static int TrophyChangeNum = 0;

    /// <summary>
    /// 清除本地的token数据
    /// </summary>
    public static void ClearTokenData ()
    {
        // PlayerPrefs.DeleteKey(HttpService.HTTP_URL + "_Token");
    }
}
