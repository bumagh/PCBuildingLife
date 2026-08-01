using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.Events;

public static class Tools
{
    public static bool isDebug = Application.platform == RuntimePlatform.WindowsEditor;
    public static string DictionaryToJson(Dictionary<string, object> data)
    {
        StringBuilder jsonBuilder = new StringBuilder();
        // 开始构建 JSON 对象
        jsonBuilder.Append("{");

        // 遍历字典中的每个键值对
        bool first = true; // 标记是否是第一个元素，用来控制逗号的位置
        foreach (var entry in data)
        {
            if (!first)
            {
                jsonBuilder.Append(",");  // 如果不是第一个元素，添加逗号
            }
            first = false;

            // 添加键
            jsonBuilder.Append($"\"{entry.Key}\":");

            // 判断值的类型，并根据类型转化为合适的 JSON 格式
            if (entry.Value is string)
            {
                jsonBuilder.Append($"\"{entry.Value}\"");
            }
            else if (entry.Value is bool)
            {
                jsonBuilder.Append(entry.Value.ToString().ToLower());  // 布尔值转换为小写的 true/false
            }
            else if (entry.Value is int || entry.Value is float || entry.Value is double)
            {
                jsonBuilder.Append(entry.Value.ToString());  // 数字值直接使用其字符串表示
            }
            else
            {
                jsonBuilder.Append("null");  // 如果是 null 类型，添加 "null"
            }
        }

        // 结束 JSON 对象
        jsonBuilder.Append("}");

        return jsonBuilder.ToString();
    }
    public static string GetHourAndMinute(string timeString)
    {
        // 尝试将时间字符串解析为 DateTime 对象
        if (DateTime.TryParse(timeString, out DateTime dateTime))
        {
            // 返回 "小时:分钟" 格式的字符串
            return $"{dateTime.Hour:D2}:{dateTime.Minute:D2}";
        }
        else
        {
            // 如果解析失败，返回空字符串或错误提示
            return "Invalid time format";
        }
    }
}
