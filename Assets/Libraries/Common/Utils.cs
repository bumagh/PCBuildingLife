
using System;
using System.Collections.Generic;
using System.Reflection;
using DG.Tweening;
using Newtonsoft.Json;
using UnityEngine;
using UnityEngine.UI;
using Random = UnityEngine.Random;

public class Utils
{
    /// <summary>
    /// 将16进制的颜色表示转换为c#的Color实例 (字符串首字应该为#号，如"#ffeedd")
    /// </summary>
    /// <param name="hexStr"></param>
    public static Color GetColorFromHex(string hexStr)
    {
        ColorUtility.TryParseHtmlString(hexStr, out Color color);
        return color;
    }

    /// <summary>
    /// 对象转为json
    /// </summary>
    /// <param name="obj"></param>
    /// <param name="indented">是否需要缩进格式</param>
    /// <returns></returns>
    public static string ObjToJson(object obj, bool indented = false)
    {
        if (indented)
        {
            return JsonConvert.SerializeObject(obj, Formatting.Indented);
        }
        else
        {
            return JsonConvert.SerializeObject(obj);
        }
    }

    /// <summary>
    /// 根据类名获取对应的实例
    /// </summary>
    public static object GetInstanceByClassName(string className)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        var instance = assembly.CreateInstance(className);
        return instance;
    }

    /// <summary>
    /// 返回数字的2位字符串形式，如果数字是0~9，则补一位0。如:1->"01",大于9则直接返回
    /// </summary>
    /// <param name="number"></param>
    /// <returns></returns>
    public static string ZeroPrefix(int number)
    {
        return (0 <= number && number <= 9) ? ("0" + number) : number.ToString();
    }

    /// <summary>
    /// 返回数字的3位字符串形式，如果数字是0~9，则补一位00。如:1->"001"，10到99，补1个0，如33->"033"
    /// </summary>
    /// <param name="number"></param>
    /// <returns></returns>
    public static string ZeroPrefixTo3(int number)
    {
        if (number < 0)
        {
            Debug.LogError("检测到负数,请检查：" + number);
            return "000";
        }
        else if (0 <= number && number <= 9)
        {
            return "00" + number;
        }
        else if (10 <= number && number <= 99)
        {
            return "0" + number;
        }
        else
        {
            return number.ToString();
        }
    }

    /// <summary>
    /// List<Vector2>转换为List<Vector3>,z位置补0
    /// </summary>
    /// <param name="v2List"></param>
    /// <returns></returns>
    public static List<Vector3> ListV2ToV3(List<Vector2> v2List)
    {
        List<Vector3> v3List = new List<Vector3>();
        for (int i = 0; i < v2List.Count; i++)
        {
            v3List.Add(new Vector3(v2List[i].x, v2List[i].y, 0));
        }

        return v3List;
    }

    /// <summary>
    /// 计算指定的方向与Y轴向右方向的夹角度数,返回一个0~360的表示
    /// </summary>
    /// <param name="dir"></param>
    /// <returns></returns>
    public static float CalcAngleWithV3Right(Vector3 dir)
    {
        float angle = Vector3.SignedAngle(Vector3.right, dir, Vector3.forward);

        if (angle < 0f)
        {
            angle += 360f;
        }

        return angle;
    }

    /// <summary>
    ///DateTime类型转换为时间戳(毫秒值)
    /// ref:https://www.cnblogs.com/Ivan-v/p/4829544.html
    /// </summary>
    public static long DateToTicks(DateTime? time)
    {
        return (
                (time.HasValue ? time.Value.Ticks : DateTime.Parse("1990-01-01").Ticks)
                - 621355968000000000
            ) / 10000;
    }

    /// <summary>
    ///  时间戳(毫秒值)String转换为DateTime类型转换
    /// </summary>
    public static DateTime TicksToDate(string time)
    {
        return new DateTime((Convert.ToInt64(time) * 10000) + 621355968000000000);
    }

    /// <summary>
    /// 小时分钟秒格式化，给定秒数，返回m时n分这种格式，如8h12m56s
    /// </summary>
    /// <param name="sec"></param>
    /// <returns></returns>
    public static string HourFormats(int sec)
    {
        if (sec >= 3600)
        {
            int h = sec / 3600;
            int m = sec % 3600 / 60;
            int s = sec % 3600 % 60;

            return string.Format("{0}h{1}m{2}s", h, m, s);
        }
        else if (sec < 3600 && sec >= 60)
        {
            int m = sec / 60;
            int s = sec % 60;
            return string.Format("{0}m{1}s", m, s);
        }
        else
        {
            return string.Format("{0}s", sec);
        }
    }

    /// <summary>
    /// 小时分钟秒格式化，给定秒数，返回，如8h
    /// </summary>
    /// <param name="sec"></param>
    /// <returns></returns>
    public static string HourIntFormats(int sec)
    {
        if (sec >= 3600)
        {
            int h = sec / 3600;

            return string.Format("{0}h", h);
        }
        else
        {
            return "00h";
        }
    }

    /// <summary>
    /// 分钟格式化，给定秒数，返回mm:nn(分分：秒秒)这种格式
    /// </summary>
    /// <param name="sec"></param>
    /// <returns></returns>
    public static string MiniutesFormat(int sec)
    {
        string str = "";

        int min = sec / 60; //分钟数
        int second = sec - min * 60;

        str += min < 10 ? "0" + min : min.ToString();
        str += ":";

        if (second < 10)
        {
            str += "0" + second;
        }
        else
        {
            str += second.ToString();
        }

        return str;
    }

    /// <summary>
    /// 小时格式化，给分钟数，返回m时n分这种格式，如8h12min
    /// </summary>
    /// <param name="min"></param>
    /// <returns></returns>
    public static string HourFormat(int min)
    {
        int hour = min / 60; //小时数
        int minute = min - hour * 60; //不足一小时的分钟数

        string str = (hour < 1 ? "" : hour + "h ") + minute + "min";

        return "Offline Time :" + str;
    }

    /// <summary>
    /// 小时分钟秒格式化，给定秒数，返回m时 如1天 或者1小时 或者1分钟 或者1秒
    /// </summary>
    /// <param name="sec"></param>
    /// <returns></returns>
    public static string DayHourFormats(int sec)
    {
        if (sec >= 3600)
        {
            int h = sec / 3600;
            if (h >= 24)
            {
                int day = h / 24;
                if (day >= 365)
                {
                    string yearString = "年";
                    int year = day / 365;
                    return $"{year}{yearString}";
                }
                string dayString = "天";
                return $"{day}{dayString}";
            }
            int m = sec % 3600 / 60;
            int s = sec % 3600 % 60;
            string hourString = "小时";
            return $"{h}{hourString}";
        }
        else if (sec < 3600 && sec >= 60)
        {
            int m = sec / 60;
            int s = sec % 60;
            string mimString = "分钟";
            return $"{m}{mimString}";
        }
        else
        {
            string sString = "秒";
            return $"{sec}{sString}";
        }
    }

    /// <summary>
    /// 获取鼠标相对于指定对象的本地坐标(以及世界坐标)
    /// </summary>
    /// <param name="worldPos">true表示获取世界坐标</param>
    /// <returns></returns>
    public static Vector3 GetMousePosition(Transform tf, bool enWorldPos = false)
    {
        Vector3 worldPos = Camera.main.ScreenToWorldPoint(Input.mousePosition);
        //修正Z轴尝
        worldPos.z = tf.position.z;

        Vector3 localPos = tf.transform.InverseTransformPoint(worldPos);
        //Debug.Log("鼠标位置：" + localPos);

        if (enWorldPos)
        {
            return worldPos;
        }
        return localPos;
    }

    /// <summary>
    /// 实例化一个对象，位置归零，缩放归一
    /// </summary>
    /// <param name="origin"></param>
    /// <param name="parent"></param>
    /// <returns></returns>
    public static GameObject CreateObj(GameObject origin, Transform parent)
    {
        GameObject go = GameObject.Instantiate(origin);
        Transform tf = go.transform;
        if (parent != null)
        {
            tf.SetParent(parent);
        }
        else
        {
            GameObject.Destroy(go);
            return null;
        }
        tf.localPosition = UnityEngine.Vector3.zero;
        tf.localScale = UnityEngine.Vector3.one;

        return go;
    }

    /// <summary>
    /// 实例化一个对象，位置归零，缩放归一
    /// </summary>
    /// <param name="origin"></param>
    /// <param name="parent"></param>
    /// <returns></returns>
    public static GameObject CreateObj(string prefabPath, Transform parent = null)
    {
        GameObject prefab = Resources.Load<GameObject>(prefabPath);
        GameObject go = GameObject.Instantiate(prefab);
        Transform tf = go.transform;
        if (parent != null)
        {
            tf.SetParent(parent);
        }
        tf.localPosition = UnityEngine.Vector3.zero;
        tf.localScale = UnityEngine.Vector3.one;

        return go;
    }

    /// <summary>
    /// 返回当前日期与时间，格式为"yyyy-MM-dd HH:mm:ss:fff"
    /// </summary>
    /// <returns></returns>
    public static string GetCurrentTime()
    {
        return System.DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss:fff");
    }

    /// <summary>
    /// 在指定的整型范围内进行一次roll点动作，如果在目标概率内则返回true，否则返回false
    /// </summary>
    /// <param name="benginVal"></param>
    /// <param name="endValue"></param>
    /// <returns></returns>
    public static bool Roll(int targetProb, int rangeBegin = 1, int rangeEnd = 100)
    {
        if (targetProb > rangeEnd)
        {
            Debug.LogErrorFormat("目标概率{0}超出范围{1}~{2}", targetProb, rangeBegin, rangeEnd);
            return false;
        }

        int random = Random.Range(rangeBegin, rangeEnd + 1);
        Debug.Log($"目标概率：{targetProb},随机范围[{rangeBegin},{rangeEnd}],命中：{random}");
        return random < targetProb ? true : false;
    }

    /// <summary>
    /// 求指定两点（构成的线段）的垂直平分线上已知x点的一个坐标
    /// </summary>
    /// <param name="p1"></param>
    /// <param name="p2"></param>
    public static Vector2 PerpendicularBisector(Vector2 p1, Vector2 p2, float xInLine)
    {
        //线段中点坐标
        Vector2 cp = new Vector2((p1.x + p2.x) / 2f, (p1.y + p2.y) / 2f);

        //该线段的斜率
        float k = (p2.y - p1.y * 1f) / (p2.x - p1.x);

        //垂直平分线的斜率为 -1 / k
        float vk = -1f / k;

        //垂直平分线上的点的x坐标
        float x = xInLine;
        //垂直平台线上的点的y坐标
        float y;

        //点斜式方式y = k(x -a) + b ,（a,b） 为直线上的点
        //计算方程如下：
        y = vk * (x - cp.x) + cp.y;

        return new Vector2(x, y);
    }

    /// <summary>
    /// 执行放大动画(放大1.2倍，然后还原) -- 适用于窗口出现
    /// </summary>
    public static void DoZoomInAnim(Transform target, Action cb = null)
    {
        target
            .DOScale(1.2f, 0.2f)
            .OnComplete(
                delegate
                {
                    target
                        .DOScale(1f, 0.2f)
                        .OnComplete(
                            delegate
                            {
                                cb?.Invoke();
                            }
                        );
                }
            );
    }

    /// <summary>
    /// 执行缩小动画(从1缩放到0) -- 适用于窗口关闭
    /// </summary>
    public static void DoZoomOutAnim(Transform target, Action cb = null)
    {
        Transform mask = target.Find("Mask");
        if (mask != null)
        {
            mask.gameObject.SetActive(false);
        }
        target
            .DOScale(0f, 0.2f)
            .OnComplete(
                delegate
                {
                    cb?.Invoke();
                }
            );
    }

    /// <summary>
    /// 轮盘赌算法
    /// </summary>
    /// <param name="weightArr">所有个体的权重值</param>
    /// <returns>返回被选中个体索引值</returns>
    /// 参考：https://www.cnblogs.com/gaosheng12138/p/7534956.html
    public static int RouletteAlogrithm(int[] weightArr)
    {
        //个体概率(个体权重/总权重)
        float[] unitProbabilities = new float[weightArr.Length];

        //总权重
        float sumWeight = 0f;
        for (int i = 0; i < weightArr.Length; i++)
        {
            sumWeight += weightArr[i];
        }
        //计算个体概率
        for (int j = 0; j < weightArr.Length; j++)
        {
            unitProbabilities[j] = weightArr[j] / sumWeight;
        }

        //生成一个0~1的随机数
        float random = UnityEngine.Random.Range(0f, 1f);
        //命中索引值
        int hitIndex = 0;
        //累计概率
        float accumulateProb = 0f;

        //判断随机数落在累计概率的哪个区间
        for (int k = 0; k < weightArr.Length; k++)
        {
            accumulateProb += unitProbabilities[k];

            if (random <= accumulateProb)
            {
                hitIndex = k;
                break;
            }
        }

        return hitIndex;
    }

    /// <summary>
    /// 将数组输出为字符串表示（只适用非对象型数组）
    /// </summary>
    /// <param name="list"></param>
    /// <returns></returns>
    public static string PrintArray<T>(T[] array)
    {
        string printStr = "[";
        for (int i = 0; i < array.Length; i++)
        {
            printStr += array[i];
            if (i != array.Length - 1)
            {
                printStr += ",";
            }
        }
        printStr += "]";
        return array.Length + ":" + printStr;
    }

    /// <summary>
    /// 将List转为字符串显示，需要指定类型，以及元素到字符串的转换方法，不指定则调用元素的ToString方法
    /// </summary>
    /// <param name="list">目标List</param>
    /// <param name="formatter">将元素转换为字符串的方法</param>
    /// <returns></returns>
    public static string ListToString<T>(List<T> list, Func<T, string> formatter = null)
    {
        Debug.Log("Count:" + list.Count);
        string printStr = "[";
        for (int i = 0; i < list.Count; i++)
        {
            if (formatter == null)
            {
                printStr += string.Format("[{0}]->{1},", i, list[i].ToString());
            }
            else
            {
                printStr += string.Format("[{0}]->{1},", i, formatter(list[i]));
            }
        }
        printStr += "]";
        return printStr;
    }

    /// <summary>
    ///  将","分隔的字符串转换为相应的整形数组 （将字符串"[5,10,15]"转换为int[]）
    /// </summary>
    /// <param name="str"></param>
    /// <returns></returns>
    public static int[] CommaStr2IntArr(string strs)
    {
        //去掉前后中括号
        strs = strs.Remove(0, 1);
        strs = strs.Remove(strs.Length - 1, 1);

        //根据逗号进行分割
        string[] arrStr = strs.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);

        //字符数组转换为整形数组
        int[] arrInt = new int[arrStr.Length];
        for (int i = 0; i < arrStr.Length; i++)
        {
            arrInt[i] = int.Parse(arrStr[i]);
        }
        return arrInt;
    }

    /// <summary>
    /// 克隆一个对象(适用于全字段对象(即字段的类型为基本数据类型))
    /// </summary>
    /// <param name="sampleObject"></param>
    /// <returns></returns>
    public static object Clone(object sampleObject)
    {
        Type t = sampleObject.GetType();
        FieldInfo[] fields = t.GetFields();
        object obj = t.InvokeMember("", BindingFlags.CreateInstance, null, sampleObject, null);
        foreach (FieldInfo field in fields)
        {
            field.SetValue(obj, field.GetValue(sampleObject));
        }
        return obj;
    }

    /// <summary>
    /// 抢红包算法（将一定总数，随机分成指定的分数）
    /// </summary>
    /// <param name="totalValue">总数值</param>
    /// <param name="partCount">份数</param>
    /// <param name="randomRangeRatio">随机范围倍数</param>
    /// <param name="minValue">最小值</param>
    public static int[] RedEnvelopeAlgorithm(
        int totalValue,
        int partCount,
        float randomRangeRatio = 2f,
        int minValue = 2
    )
    {
        //数组长度
        int arrayLen = partCount;
        int[] partVal = new int[arrayLen];

        for (int i = 0; i < arrayLen; i++)
        {
            float min = minValue; //是小数量
            float max = 1f * totalValue / partCount * randomRangeRatio; //最大数

            float random = Random.Range(min, max);

            //如果是最后一个值，则不用再随机（剩余值就是最后一项的值）
            if (i == arrayLen - 1)
            {
                random = totalValue;
            }

            int rInt = Mathf.RoundToInt(random);
            partVal[i] = rInt;

            totalValue -= rInt;
            partCount--;
        }
        //Debug.Log("随机分配结果：" + Utils.PrintArray<int>(partVal));

        return partVal;
    }

    /// <summary>
    /// 根据两个端点，获取一条弧线路径点
    /// </summary>
    public static List<Vector3> GetArcPathPoint(Vector3 startPos, Vector3 endPos)
    {
        //在两点间的x轴上随机取一点
        float randomX = Random.Range(startPos.x, endPos.x);
        //对应的点坐标
        Vector2 relatedPoint = Utils.PerpendicularBisector(
            new Vector2(startPos.x, startPos.y),
            new Vector2(endPos.x, endPos.y),
            randomX
        );

        //当这两点y坐标相等时，(为避免出现弯曲度极大的情况，只在这条线段构成的正方形范围内取值)
        if (Math.Abs(startPos.y - endPos.y) < 0.5f)
        {
            float randomY = Random.Range(startPos.y, endPos.y) * -0.3f;
            relatedPoint = new Vector2(randomX, randomY);
        }

        List<Vector3> waypoints = new List<Vector3>()
        {
            new Vector3(startPos.x, startPos.y, startPos.z),
            new Vector3(relatedPoint.x, relatedPoint.y, startPos.z),
            new Vector3(endPos.x, endPos.y, startPos.z),
        };

        return waypoints;
    }

    /// <summary>
    /// 取时间戳，高并发情况下会有重复。想要解决这问题请使用sleep线程睡眠1毫秒。
    /// </summary>
    /// <param name="AccurateToMilliseconds">精确到毫秒</param>
    /// <returns>返回一个长整数时间戳</returns>
    public static long GetTimeStamp(bool AccurateToMilliseconds = false)
    {
        if (AccurateToMilliseconds)
        {
            // 使用当前时间计时周期数（636662920472315179）减去1970年01月01日计时周期数（621355968000000000）除去（删掉）后面4位计数（后四位计时单位小于毫秒，快到不要不要）再取整（去小数点）。

            //备注：DateTime.Now.ToUniversalTime不能缩写成DateTime.Now.Ticks，会有好几个小时的误差。

            //621355968000000000计算方法 long ticks = (new DateTime(1970, 1, 1, 8, 0, 0)).ToUniversalTime().Ticks;

            return (DateTime.Now.ToUniversalTime().Ticks - 621355968000000000) / 10000;
        }
        else
        {
            //上面是精确到毫秒，需要在最后除去（10000），这里只精确到秒，只要在10000后面加三个0即可（1秒等于1000毫米）。
            return (DateTime.Now.ToUniversalTime().Ticks - 621355968000000000) / 10000000;
        }
    }

    /// <summary>
    /// 取时间戳，高并发情况下会有重复。想要解决这问题请使用sleep线程睡眠1毫秒。
    /// </summary>
    /// <param name="AccurateToMilliseconds">精确到毫秒</param>
    /// <returns>返回一个长整数时间戳</returns>
    // public static long GetTimeStampByServerTime(bool AccurateToMilliseconds = false)
    // {
    //     if (AccurateToMilliseconds)
    //     {
    //         // 使用当前时间计时周期数（636662920472315179）减去1970年01月01日计时周期数（621355968000000000）除去（删掉）后面4位计数（后四位计时单位小于毫秒，快到不要不要）再取整（去小数点）。

    //         //备注：DateTime.Now.ToUniversalTime不能缩写成DateTime.Now.Ticks，会有好几个小时的误差。

    //         //621355968000000000计算方法 long ticks = (new DateTime(1970, 1, 1, 8, 0, 0)).ToUniversalTime().Ticks;

    //         return GetTimeStamp(true) - PvPManager.serverToLocalTimeDifValue * 1000;
    //     }
    //     else
    //     {
    //         //上面是精确到毫秒，需要在最后除去（10000），这里只精确到秒，只要在10000后面加三个0即可（1秒等于1000毫米）。
    //         return GetTimeStamp() - PvPManager.serverToLocalTimeDifValue;
    //     }
    // }

    /// <summary>
    /// 时间戳反转为时间，有很多中翻转方法，但是，请不要使用过字符串（string）进行操作，大家都知道字符串会很慢！
    /// </summary>
    /// <param name="TimeStamp">时间戳</param>
    /// <param name="AccurateToMilliseconds">是否精确到毫秒</param>
    /// <returns>返回一个日期时间</returns>
    public static DateTime GetTime(long TimeStamp, bool AccurateToMilliseconds = false)
    {
        System.DateTime startTime = TimeZone.CurrentTimeZone.ToLocalTime(
            new System.DateTime(1970, 1, 1)
        ); // 当地时区
        if (AccurateToMilliseconds)
        {
            return startTime.AddTicks(TimeStamp * 10000);
        }
        else
        {
            return startTime.AddTicks(TimeStamp * 10000000);
        }
    }

    /// <summary>
    /// 将数据表中的比例值转换为标准浮点表示
    /// 由于数据表中比值型数据采用【万分比】的形式，相应数据需除以10000,才能得到标准浮点值。
    /// 转换过程如：2000-> 2000/10000 -> 0.2f
    /// </summary>
    /// <param name="configValue"></param>
    /// <returns></returns>
    public static float GetStandardRatio(float configValue)
    {
        return configValue / 10000f;
    }

    #region Debug.Log相关
    /// <summary>
    /// 输出info级别的彩色日志
    /// </summary>
    /// <param name="color">颜色范围为Color类型所指定的颜色</param>
    /// <param name="content">打印的对象</param>
    /// <param name="bold">粗体模式</param>
    /// <param name="module">所属游戏模块（仅为区分日志之用）</param>
    public static void ColorLog(
        LogColor color,
        object content,
        bool bold = false,
        GameModule module = GameModule.None
    )
    {
        string moduleName = module == GameModule.None ? "" : $"[{module}]";
        if (bold)
        {
            Debug.Log($"<b>{moduleName}<color={color}>{content}</color></b>");
        }
        else
        {
            Debug.Log($"{moduleName}<color={color}>{content}</color>");
        }
    }
    #endregion
    /// <summary>
    /// 根据实际时间返回指定格式
    /// </summary>
    /// <param name="ts"></param>
    /// <returns></returns>
    public static string TimeSpanFormat(TimeSpan ts)
    {
        string result = "";
        // if (ts.Days > 0)
        // {
        //     result = $"{ts.Days}{TableDataMgr.GetTextByID(23500021)}";
        // }
        // else
        // {
        //     result = $"{ts.Hours:0}h{ts.Minutes:0}m{ts.Seconds:0}s";
        //     if (ts.Hours < 0)
        //     {
        //         result = $"{ts.Minutes:0}m{ts.Seconds:0}s";
        //     }
        // }
        return result;
    }

    public static string TimeSpanFormatHoursAndMin(TimeSpan ts)
    {
        string result = "";
        // if (ts.Days > 0)
        // {
        //     result = $"{ts.Days}{TableDataMgr.GetTextByID(23500021)}";
        // }
        // else
        // {
        //     result =
        //         $"{ts.Hours:0}{TableDataMgr.GetTextByID(23500022)}{ts.Minutes:0}{TableDataMgr.GetTextByID(23500023)}";
        //     if (ts.Hours < 0)
        //     {
        //         result =
        //             $"{ts.Minutes:0}{TableDataMgr.GetTextByID(23500023)}{ts.Seconds:0}{TableDataMgr.GetTextByID(23500024)}";
        //     }
        // }
        return result;
    }

    public static void SetBgImage(Image image, List<Sprite> sprites)
    {
        float percent = (float)Screen.height / Screen.width;
        ColorLog(LogColor.magenta, $"屏幕宽{Screen.width}  屏幕高：{Screen.height}  宽高比：{percent}");
        if (percent >= 2 || percent < 1.34)
        {
            image.sprite = sprites[1];
        }
        else
        {
            image.sprite = sprites[0];
        }
        image.SetNativeSize();
    }

    /// <summary>
    /// 数字格式化
    /// 0-9,999显示实际数字
    /// 10,000-9,999,999显示K ->10k~9999k
    /// 10,000,000-9999,999,999显示M ->10M~9999M
    /// 即4位数字+单位
    ///
    /// 单位表示：      k m b t  aa ab ac ad ae af ag
    /// 分别对应10的次方 3 6 9 12 15 18 21 24 27 30 33
    /// </summary>
    /// <param name="num"></param>

    public static string NumberFormat(uint num)
    {
        string numStr = "";

        if (num < (1e4 - 1))
        {
            if (num >= 0)
            {
                numStr = num.ToString();
            }
            else
            {
                Debug.LogError("negative number exception:" + num);
            }
        }
        else if (num < (1e7 - 1))
        {
            numStr = num / ((uint)(1e3)) + "K";
        }
        else if (num < (1e10 - 1))
        {
            numStr = num / ((uint)(1e6)) + "M";
        }
        //Debug.LogFormat("数字格式化：{0},{1}", num, numStr);
        return numStr;
    }

    public static int GetCardNameFromSrcName(string srcName)
    {
        int cardName = 11200101;

        switch (srcName)
        {
            case "houxiaozhan":
                cardName = 11200101;
                break;
            case "houxiaodun":
                cardName = 11200102;
                break;
            case "houxiaoshe":
                cardName = 11200201;
                break;
            case "niudazhuang":
                cardName = 11200202;
                break;
            case "xiongdazhuang":
                cardName = 11200203;
                break;
            case "tuxiaoguai":
                cardName = 11200301;
                break;
            case "huoqiu":
                cardName = 11200302;
                break;
            case "jianyu":
                cardName = 11200303;
                break;
            case "douzhanshengfo":
                cardName = 11200401;
                break;
            case "qitiandasheng":
                cardName = 11200402;
                break;
            case "liuermihou":
                cardName = 11200403;
                break;
            case "zouhuorumo":
                cardName = 11200404;
                break;
            default:
                break;
        }

        return cardName;
    }

    public static string GetSrcNameFromCardName(int cardName)
    {
        string srcName = "houxiaozhan";
        switch (cardName)
        {
            case 11200101:
                srcName = "houxiaozhan";
                break;
            case 11200102:
                srcName = "houxiaodun";
                break;
            case 11200201:
                srcName = "houxiaoshe";
                break;
            case 11200202:
                srcName = "niudazhuang";
                break;
            case 11200203:
                srcName = "xiongdazhuang";
                break;
            case 11200301:
                srcName = "tuxiaoguai";
                break;
            case 11200302:
                srcName = "huoqiu";
                break;
            case 11200303:
                srcName = "jianyu";
                break;
            case 11200401:
                srcName = "douzhanshengfo";
                break;
            case 11200402:
                srcName = "qitiandasheng";
                break;
            case 11200403:
                srcName = "liuermihou";
                break;
            case 11200404:
                srcName = "zouhuorumo";
                break;
            default:
                break;
        }

        return srcName;
    }

    public static bool[,] GetGridFromPoolBlockArr(bool[] poolBlockArr)
    {
        bool[,] grid = new bool[2, 4];
        for (int i = 0; i < 2; i++)
        {
            for (int j = 0; j < 4; j++)
            {
                grid[i, j] = poolBlockArr[i * 4 + j];
            }
        }
        return grid;
    }

    // public static int[,] GetShapeFromMassif(int[] massif)
    // {
    //     if (massif.Length != 2)
    //         return default;
    //     int[,] shape = new int[massif[0], massif[1]];
    //     for (int i = 0; i < massif[0]; i++)
    //     {
    //         for (int j = 0; j < massif[1]; j++)
    //         {
    //             shape[i, j] = 1;
    //         }
    //     }
    //     return shape;
    // }
    public static List<(int, int)> GetShapeFromMassif(int[] massif)
    {
        if (massif.Length != 2)
        {
            // 如果massif长度不是2，可以抛出一个异常或者返回一个空列表
            // 这里选择返回一个空列表
            return new List<(int, int)>();
        }

        int width = massif[0];
        int height = massif[1];

        List<(int, int)> shape = new List<(int, int)>();

        for (int i = 0; i < height; i++)
        {
            for (int j = 0; j < width; j++)
            {
                // 将每个格子的坐标添加到列表中
                shape.Add((i, j)); // 注意：这里我假设你想按照(x, y)的顺序添加，但在二维数组中，通常y是行索引（高度），x是列索引（宽度）
                // 如果你希望按照二维数组索引的顺序（即先遍历行再遍历列），那么上面的添加方式是正确的
                // 如果你想要的是更自然的(宽度索引, 高度索引)顺序，那么可以保持不变
            }
        }

        return shape;
    }

    public static bool TryPlaceShape(bool[,] grid, int n, int m, List<(int, int)> shape)
    {
        for (int x = 0; x <= n - shape.Count; x++)
        {
            for (int y = 0; y <= m - shape[0].Item2; y++)
            {
                if (CanPlaceShape(grid, x, y, shape))
                {
                    return true;
                }
            }
        }
        return false;
    }
    public static List<(int,int)> GetNewShapeFromStartPos((int,int) startPos, List<(int,int)> shape){
        var newShape = new List<(int,int)>();
       for (int i = 0; i < shape.Count; i++)
       {
            newShape.Add((shape[i].Item1+startPos.Item1, shape[i].Item2+startPos.Item2));
       }
        return newShape;
    }
    public static bool CanPlaceShape(bool[,] grid, int startX, int startY, List<(int, int)> shape)
    {
        for (int i = 0; i < shape.Count; i++)
        {
            int x = startX + shape[i].Item1;
            int y = startY + shape[i].Item2;
            if (x < 0 || x >= grid.GetLength(0) || y < 0 || y >= grid.GetLength(1) || !grid[x, y])
            {
                return false;
            }
        }
        return true;
    }
}

/// <summary>
/// 彩色日志（ColorLog）方法所支持的颜色
/// （这里的颜色名称与Color类相应的颜色对应）
/// </summary>
public enum LogColor
{
    red,
    green,
    blue,
    white,
    black,
    yellow,
    cyan,
    magenta,
    gray,
    grey
}

/// <summary>
/// 功能模块
/// </summary>
public enum GameModule
{
    None,

    /// <summary>
    /// 英雄技能
    /// </summary>
    HeroSkill,

    /// <summary>
    /// 英雄技能buff
    /// </summary>
    HeroSkillBuff,

    /// <summary>
    /// boss技能
    /// </summary>
    BossSkill,

    /// <summary>
    /// boss技能buff
    /// </summary>
    BossSkillBuff,

    /// <summary>
    /// 强化卡
    /// </summary>
    BuffCard
}
