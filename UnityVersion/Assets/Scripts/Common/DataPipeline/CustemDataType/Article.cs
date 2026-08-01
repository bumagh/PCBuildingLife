/**
* UnityVersion: 2019.3.15f1
* FileName:     Article.cs
* Author:       TANYUQING
* CreateTime:   2020/09/07 10:51:39
* Description:  
*/
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 数据生产线自定义类型：物品
/// </summary>
public class Article
{
    private static readonly char[] Common_Separators = new char[] { '|', ',' };
    private static readonly string[] Special_Characters = new string[] { "(", ")", "[", "]", "{", "}" };

    /// <summary>
    /// 物品ID
    /// </summary>
    public int id;
    /// <summary>
    /// 物品数量
    /// </summary>
    public int count;

    /// <summary>
    /// 子物品数组
    /// </summary>
    public Article[] subArticles = null;

    public Article()
    {

    }

    public Article(int id, int count)
    {
        this.id = id;
        this.count = count;
    }

    public override string ToString()
    {
        return Utils.ObjToJson(this);
    }

    /// <summary>
    /// 将[1,5000]这种格式的字符转化为Article对象
    /// </summary>
    /// <returns></returns>
    public static Article Parse (string str)
    {
        str = CleanString(str);

        if (!IsStandardArticleFormat(str))
        {
            UnityEngine.Debug.LogError(str + " 格式不符合，请检查。示例[1,5000]");
            return null;
        }
        var intArr = Newtonsoft.Json.JsonConvert.DeserializeObject<int[]>(str);

        return new Article(intArr[0], intArr[1]);
    }

    /// <summary>
    /// 将[20203,5,[[2,3000]]]这种格式的字符转化为带子物品的Article对象
    /// 只适用于一主物体带多个单级子物体的情况。若子物品仍为嵌套物品，由需要重写相关解析方法
    /// </summary>
    /// <returns></returns>
    public static Article ParseNested(string str = "[20203,5,[[2,3000]]]")
    {
        string temp = str;
        //去除[],(),{}等特殊符号
        for (int i = 0; i < Special_Characters.Length; i++)
        {
            temp = temp.Replace(Special_Characters[i], "");
        }

        str = temp.Trim();

        //用','分割符划分为数组
        string[] stringArray = str.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);

        //构造基本物品信息
        Article article = new Article
        {
            id = int.Parse(stringArray[0]),
            count = int.Parse(stringArray[1])
        };

        //计算子物品个数(先减去主物品所占两位，再除2[一个物品需占用两位])
        int subItemCount = (stringArray.Length - 2) / 2;
        if (subItemCount > 0)
        {
            List<Article> subArticles = new List<Article>();
            for (int i = 0; i < subItemCount; i++)
            {
                Article subArticle = new Article
                {
                    id = int.Parse(stringArray[2 + 2 * i]),
                    count = int.Parse(stringArray[2 + 2 * i + 1])
                };
                subArticles.Add(subArticle);
            }
            article.subArticles = subArticles.ToArray();
        }

        return article;
    }

    /// <summary>
    /// 解析为物品数组
    /// </summary>
    /// <returns></returns>
    public static Article[] ParseToArticleArr (string targetStr)
    {
        List<Article> articles = new List<Article>();
        //字符串格式如下：
        //string str = "[[1,5000],[50301,1],[20203,5,[[2,3000]]]]";

        //Debug.Log("待解析串：" + targetStr);
        var objArray = JsonConvert.DeserializeObject<object[]>(targetStr);
        for (int i = 0; i < objArray.Length; i++)
        {
            var objStr = Article.CleanString(objArray[i].ToString());
            //Debug.Log(i + "->" + objStr.ToString());
            if (IsStandardArticleFormat(objStr))
            {
                Article simpleArticle = Article.Parse(objStr);
                //Debug.Log("简单字物品，直接转换为Article:" + Utils.ObjToJson(simpleArticle));
                articles.Add(simpleArticle);
            }
            else
            {
                Article nestedArticle = Article.ParseNested(objStr);
                //Debug.Log("嵌套物品，转换为复杂Article:" + Utils.ObjToJson(nestedArticle));
                articles.Add(nestedArticle);
            }
        }

        return articles.ToArray();
    }

    /// <summary>
    /// 去除字符串中的\r \n和空格
    /// </summary>
    /// <param name="newStr"></param>
    /// <returns></returns>
    public static string CleanString(string dirtyStr)
    {
        string tempStr = dirtyStr.Replace("\n", "");
        tempStr = tempStr.Replace("\r", "");
        tempStr = tempStr.Replace(" ", "");
        return tempStr;
    }

    /// <summary>
    /// 判断字符串是否符合[1,5000]这样的格式，即[数字1,数字2]
    /// </summary>
    /// <returns></returns>
    private static bool IsStandardArticleFormat(string str)
    {
        //首字符是否为[
        bool startCharQualified = str.Substring(0, 1) == "[";
        //末字符是否为]
        bool endCharQualified = str.Substring(str.Length - 1, 1) == "]";

        //是否包含且只包含一个"," //TODO: 这里没检测逗号位置在两数中间，后续有空可完善。
        bool isIncludeComma = false;
        var commaIdx = str.IndexOf(',');
        if (commaIdx != -1 && commaIdx == str.LastIndexOf(','))
        {
            isIncludeComma = true;
        }

        return startCharQualified && endCharQualified && isIncludeComma;
    }
}
