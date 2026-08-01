// /**
// * UnityVersion: 2019.3.15f1
// * FileName:     UsingSample.cs
// * Author:       TANYUQING
// * CreateTime:   2020/09/08 10:25:53
// * Description:  
// */
// using System.Collections;
// using System.Collections.Generic;
// using System.IO;
// using UnityEngine;

// /// <summary>
// /// TableDataMgr使用示例
// /// </summary>
// public class UsingSample : MonoBehaviour
// {
//     // Start is called before the first frame update
//     void Start()
//     {
//         GetRowDataById();
//         //GetAllTableRecord();
//         //GetRangeTypeData();
//         //GetArticleTypeData();
//     }

//     /// <summary>
//     /// 根据id获取一行的数据，这里以"充值码表.xlsx"第1行数据为例
//     /// </summary>
//     public void GetRowDataById ()
//     {
//          var rowData = TableDataMgr.GetSingleProductIdTableData(100);
//          UnityEngine.Debug.LogFormat("id:{0},priceText:{1},PriceCN:{2}", rowData.id, rowData.priceText, rowData.priceCN);
//     }


//     /// <summary>
//     /// 取整张表的数据，这里以"充值码表.xlsx"为例
//     /// </summary>
//     public void GetAllTableRecord ()
//     {
//         List<ProductIdTableData> tableData = TableDataMgr.GetAllProductIdTableData();
//         for (int i = 0; i < tableData.Count; i++)
//         {
//             UnityEngine.Debug.LogFormat("id:{0},priceText:{1},PriceCN:{2}", tableData[i].id, tableData[i].priceText, tableData[i].priceCN);
//         }
//     }

//     /// <summary>
//     /// 读取Range型数据，这里以"排行奖励表.xlsx"为例 
//     /// </summary>
//     public void GetRangeTypeData ()
//     {
//         var rowData = TableDataMgr.GetSingleRankingRewardsTableData(101);
//         UnityEngine.Debug.LogFormat("id:{0},Range:{1}", rowData.id, rowData.rankingRange);
//     }

//     /// <summary>
//     /// 读取Atircle型数据，这里以"排行奖励表.xlsx"为例 
//     /// </summary>
//     public void GetArticleTypeData()
//     {
//         var rowData = TableDataMgr.GetSingleRankingRewardsTableData(101);
//         //UnityEngine.Debug.LogFormat("id:{0},Article[0]:{1}", rowData.id, rowData.reward[0]);
//     }
// }
