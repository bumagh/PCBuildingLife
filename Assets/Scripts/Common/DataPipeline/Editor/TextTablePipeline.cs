/**
* UnityVersion: 2019.3.15f1
* FileName:     TextTablePipeline.cs
* Author:       TANYUQING
* CreateTime:   2020/09/07 10:51:39
* Description:  
*/
using ExcelDataReader;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Reflection;
using System.Runtime.Serialization.Formatters.Binary;
using System.Text;
using UnityEditor;
using UnityEngine;

/// <summary>
/// 文本表生产线(多个表格,多个sheet合并)
/// </summary>
public class TextTablePipeline : EditorWindow
{
    public struct DataTableMessage
    {
        public DataTable data;
        public bool main;
        public string excelName;
    }

    private const string TemplateDirectory_Common = "Assets/Scripts/ShareLibrary/DataPipeline/ScriptTemplate/";
    private const string TemplateDirectory_Asset = "Assets/Scripts/ShareLibrary/DataPipeline/ScriptTemplate/AssetTemplate/";
    private const string TemplateDirectory_Json = "Assets/Scripts/ShareLibrary/DataPipeline/ScriptTemplate/JsonTemplate/";

    private const string Path_PlayerPreferences = "../Library/TextTableBuild.dat";

    private const string TemplateFile_TableData = "TableData.txt";
    private const string TemplateFile_TableDataField = "TableDataField.txt";
    private const string TemplateFile_DataSet = "DataSet.txt";

    private const string Name_TableData = "TextTableData";
    private const string Name_TableDataSet = "TextDataSet";

    private const string FileExtension_Cs = ".cs";
    private const string FileExtension_Json = ".txt";


    private const string DataSetName = "#DataSetName#";
    private const string TableDataName = "#TableDataName#";

    private const int Row_Min = 4;
    private const int Row_TableData_Describe = 0;
    private const int Row_TableDataField_Describe = 1;
    private const int Row_TableDataField_Name = 2;
    private const int Row_TableDataField_Type = 3;

    private static TextTableBuildData buildData;
    private static List<string> excelPaths = new List<string>();
    private static List<DataTableMessage> dataTableList = new List<DataTableMessage>();
    //支持的数据类型
    private static List<string> supportedDataTypes = new List<string>()
    {
        "int","long","float","double","bool","string", "Vector2","Vector3", "Article","Range",
        "int[]","long[]","float[]","double[]","bool[]","string[]","Vector2[]","Vector3[]","Article[]","Range[]"
    };

    #region Public Method

    public static void ShowAssetEditorWindow()
    {
        TextTablePipeline window = (TextTablePipeline)GetWindow(typeof(TextTablePipeline), false, "文本表生产线(Asset)", true);
        window.Show();
        buildData.format = DataFormatEnum.Asset;
    }

    public static void ShowJsonEditorWindow()
    {
        TextTablePipeline window = (TextTablePipeline)GetWindow(typeof(TextTablePipeline), false, "文本表生产线(Json)", true);
        window.Show();
        buildData.format = DataFormatEnum.Json;
    }

    public static void UpdateTextTableToJosnWithCMD()
    {
        GetParametersFromCommandLine();
        UpdateTextTableToJosn();
    }

    public static void UpdateTextTableToAssetWithCMD()
    {
        GetParametersFromCommandLine();
        UpdateTextTableToAsset();
    }

    /// <summary>
    /// 在数据生产线生产过程中会伴随这代码编译,再编译过程中所有的变量都会重新初始化,函数也无法执行,并且后面
    /// 函数中需要用到前面编译的脚本,因此先进行编译,等编译完成后再执行后面的代码.
    /// </summary>
    public static void OnScriptsReload()
    {
        GetBuildData();
        if (buildData.updating && buildData.format == DataFormatEnum.Asset)
        {
            buildData.updating = false;
            SaveBuildData();
            Debug.Log("4.脚本编译完成重新读取数据表");
            AssetPostProcessMgr.enabled = false;
            GetAllTableDataPaths();
            ConvertExcelToDataTable();
            Debug.Log("5.更新.asset文件");
            UpdateTableDataAsset(dataTableList);
            AssetPostProcessMgr.enabled = true;
            AssetDatabase.Refresh();
            Debug.Log("6.更新完成");
        }
    }
    #endregion

    #region Private Method

    /// <summary>
    /// 从命令行获取参数设置路径
    /// </summary>
    private static void GetParametersFromCommandLine()
    {
        buildData = new TextTableBuildData();
        string[] args = System.Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == nameof(buildData.textDataDirectory))
            {
                buildData.textDataDirectory = args[i + 1];
                Debug.Log("从命令行获取参数并设置数据表路径为：" + buildData.textDataDirectory);
            }
            else if (args[i] == nameof(buildData.exportScriptDirectory))
            {
                buildData.exportScriptDirectory = args[i + 1];
                Debug.Log("从命令行获取参数并设置脚本导出路径为：" + buildData.exportScriptDirectory);
            }
            else if (args[i] == nameof(buildData.exportResourceDirectory))
            {
                buildData.exportResourceDirectory = args[i + 1];
                Debug.Log("从命令行获取参数并设置资源导出路径为：" + buildData.exportResourceDirectory);
            }
            else if (args[i] == nameof(buildData.copy))
            {
                buildData.copy = bool.Parse(args[i + 1]);
                Debug.Log("从命令行获取参数并设置是否拷贝脚本至其他目录为：" + buildData.copy);
            }
            else if (args[i] == nameof(buildData.destScriptDirectory))
            {
                buildData.destScriptDirectory = args[i + 1];
                Debug.Log("从命令行获取参数并设置脚本拷贝目录为：" + buildData.destScriptDirectory);
            }
        }
    }

    private static void UpdateTextTableToJosn()
    {
        Utf8jsonHelper.EditorInitialize();
        AssetPostProcessMgr.enabled = false;
        Debug.Log("1.读取文本表");
        GetAllTableDataPaths();
        ConvertExcelToDataTable();
        Debug.Log("2.更新cs文件");
        UpdateTableDataScript(dataTableList[0].data);
        UpdateDataSetScript(dataTableList[0].data, TemplateDirectory_Json);
        Debug.Log("3.更新json文件");
        UpdateTableDataJson(dataTableList);
        AssetPostProcessMgr.enabled = true;
        AssetDatabase.Refresh();
        Debug.Log("4.更新完成！");
    }

    private static void UpdateTextTableToAsset()
    {
        AssetPostProcessMgr.enabled = false;
        buildData.updating = true;
        Debug.Log("1.读取文本表");
        GetAllTableDataPaths();
        ConvertExcelToDataTable();
        Debug.Log("2.更新cs文件");
        UpdateTableDataScript(dataTableList[0].data);
        UpdateDataSetScript(dataTableList[0].data, TemplateDirectory_Asset);
        SaveBuildData();
        AssetPostProcessMgr.enabled = true;
        AssetDatabase.Refresh();
        if (EditorApplication.isCompiling == false)
        {
            Debug.Log("3.未产生编译行为,脚本内容没有变更,直接更新.asset文件");
            buildData.updating = false;
            SaveBuildData();
            UpdateTableDataAsset(dataTableList);
            if (buildData.copy)
            {
                CopyScriptsToSpecifiedPath();
            }
            Debug.Log("4.更新文本表完成!");
        }
        else
        {
            Debug.Log("产生编译行为,脚本内容有变更,后续逻辑等脚本编译完成后处理");
        }
    }

    /// <summary>
    /// 获取所有表数据文件路径
    /// </summary>
    /// <returns></returns>
    private static void GetAllTableDataPaths()
    {
        excelPaths.Clear();
        string[] files = Directory.GetFiles(buildData.textDataDirectory);
        for (int i = 0; i < files.Length; i++)
        {
            string fileName = files[i].Replace("\\", "/");
            if ((fileName.EndsWith(".xls") || fileName.EndsWith(".xlsx") || fileName.EndsWith(".xlsm")) && fileName.StartsWith("~$") == false)
            {
                excelPaths.Add(fileName);
            }
        }
        if (excelPaths.Count <= 0)
        {
            Debug.Log(string.Format("在{0}路径下未找到Excel文件,请检查", buildData.textDataDirectory));
        }
    }

    /// <summary>
    /// 读取数据表中所有符合条件的Sheet并将里面的数据转换为DataTable,并计算每一个Sheet的MD5值
    /// </summary>
    /// <param name="excelPath"></param>
    /// <returns></returns>
    private static void ConvertExcelToDataTable()
    {
        dataTableList.Clear();
        foreach (var onePath in excelPaths)
        {
            try
            {
                string fileName = Path.GetFileNameWithoutExtension(onePath);
                using (FileStream excelStream = File.OpenRead(onePath))
                {
                    IExcelDataReader excelReader = ExcelReaderFactory.CreateOpenXmlReader(excelStream);
                    DataSet data = excelReader.AsDataSet();
                    for (int i = 0; i < data.Tables.Count; i++)
                    {
                        DataTable item = data.Tables[i];
                        if (item.TableName.StartsWith("#") == false)
                        {
                            if (item.Rows.Count > Row_Min && item.Columns.Count > 0)
                            {
                                bool main = false;
                                if (fileName == "文本表")
                                {
                                    main = true;
                                }
                                DataTableMessage message = new DataTableMessage
                                {
                                    data = item,
                                    main = main,
                                    excelName = onePath,
                                };
                                dataTableList.Add(message);
                            }
                            else
                            {
                                Debug.LogError(string.Format("{0}表中的Sheet:{0}存在格式问题,行数或列数低于最小限制", onePath, item.TableName));
                                throw new UnityException();
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.LogErrorFormat("解析表:{0}出现问题:{1}", onePath, ex);
                throw new UnityException();
            }
        }
    }

    /// <summary>
    /// 更新TableData.cs文件
    /// </summary>
    /// <param name="data"></param>
    private static void UpdateTableDataScript(DataTable data)
    {
        //获取表数据字段的模板文件并填充内容
        string fieldTemplatePath = Path.Combine(TemplateDirectory_Common, TemplateFile_TableDataField);
        TextAsset fieldTemplate = AssetDatabase.LoadAssetAtPath(fieldTemplatePath, typeof(TextAsset)) as TextAsset;
        //获取字段内容
        StringBuilder fieldContent = new StringBuilder();
        for (int i = 0; i < data.Columns.Count; i++)
        {
            //去除不合规则的字段
            if (data.Rows[Row_TableDataField_Describe][i].ToString().StartsWith("#") == false)
            {
                string fieldType = data.Rows[Row_TableDataField_Type][i].ToString();
                string fieldName = data.Rows[Row_TableDataField_Name][i].ToString();
                string fieldDescribe = data.Rows[Row_TableDataField_Describe][i].ToString();
                if (string.Equals(fieldName,"id"))
                {
                    fieldContent.Append(string.Format(fieldTemplate.text, fieldDescribe, fieldType, fieldName));
                    break;
                }
            }
        }
        fieldContent.AppendLine("    /// <summary>");
        fieldContent.AppendLine("    /// 文本字典（Key：国家缩写；Value：文本内容）");
        fieldContent.AppendLine("    /// </summary>");
        fieldContent.AppendLine("    public Dictionary<string, string> textDic = new Dictionary<string, string>();");

        //获取TableData模板文件并填充表名与字段,创建出TableData.cs脚本
        string describe = "文本表";
        string name = Name_TableData;
        string templatePath = Path.Combine(TemplateDirectory_Common, TemplateFile_TableData);

        TextAsset tableDataTemplate = AssetDatabase.LoadAssetAtPath(templatePath, typeof(TextAsset)) as TextAsset;
        string tableDataContent = tableDataTemplate.text;
        tableDataContent = string.Format(tableDataContent, describe, name, fieldContent);
        string exprotPath = Path.Combine(buildData.exportScriptDirectory, name + FileExtension_Cs);
        File.WriteAllText(exprotPath, tableDataContent, new UTF8Encoding(true));
    }

    /// <summary>
    /// 更新DataSet.cs脚本
    /// </summary>
    /// <param name="data">数据</param>
    /// <param name="directory">模板目录</param>
    private static void UpdateDataSetScript(DataTable data, string directory)
    {
        //获取DataSet模板文件并填充表名,创建出ScriptableObject.cs脚本
        string tableDataName = Name_TableData;
        string dataSetName = Name_TableDataSet;
        string templatePath = Path.Combine(directory, TemplateFile_DataSet);
        TextAsset template = AssetDatabase.LoadAssetAtPath(templatePath, typeof(TextAsset)) as TextAsset;
        string content = template.text;
        content = content.Replace(DataSetName, dataSetName);
        content = content.Replace(TableDataName, tableDataName);
        string exprotFilePath = Path.Combine(buildData.exportScriptDirectory, dataSetName + FileExtension_Cs);
        File.WriteAllText(exprotFilePath, content, new UTF8Encoding(true));
    }

    /// <summary>
    /// 更新.json文件
    /// </summary>
    private static void UpdateTableDataJson(List<DataTableMessage> dataList)
    {
        List<object> jsonArray = new List<object>();
        Dictionary<int, KeyValuePair<bool, Dictionary<object,object>>> resultDic = new Dictionary<int, KeyValuePair<bool, Dictionary<object, object>>>();
        for (int m = 0; m < dataList.Count; m++)
        {
            DataTableMessage message = dataList[m];
            DataTable dataTable = dataList[m].data;
            for (int i = Row_Min; i < dataTable.Rows.Count; i++)
            {
                Dictionary<object, object> jsonObject = new Dictionary<object, object>();
                int id = int.Parse(dataTable.Rows[i][0].ToString());
                Dictionary<object,object> content = new Dictionary<object, object>();
                for (int j = 0; j < dataTable.Columns.Count; j++)
                {
                    if (dataTable.Rows[Row_TableDataField_Describe][j].ToString().StartsWith("#") == false)
                    {
                        string type = dataTable.Rows[Row_TableDataField_Type][j].ToString();
                        if (supportedDataTypes.Contains(type))
                        {
                            string key = dataTable.Rows[Row_TableDataField_Name][j].ToString();
                            try
                            {
                                object value = null;
                                if (string.Equals(key,"id"))
                                {
                                    value = DataSheetPipeline.GetFieldValue(type, dataTable.Rows[i][j]);
                                    jsonObject.Add(key, value);
                                }
                                else
                                {
                                    value = DataSheetPipeline.GetFieldValue(type, dataTable.Rows[i][j]);
                                    content.Add(key, value);
                                }
                            }
                            catch (Exception e)
                            {
                                Debug.LogError(string.Format("{0}表的第{1}行第{2}列解析错误,请检查！错误内容：{3}", dataTable.TableName, i + 1, j + 1, e));
                            }
                        }
                        else
                        {
                            Debug.LogError(string.Format("{0}表的第{1}列是未知的数据类型-{2}-,请检查", dataTable.TableName, j + 1, type));
                        }
                    }
                }
                jsonObject.Add("textDic", content);

                if (resultDic.ContainsKey(id))
                {
                    //列表中记录的为主表内容,
                    if (resultDic[id].Key)
                    {
                        //当前内容为副表，替换
                        if (message.main == false)
                        {
                            resultDic[id] = new KeyValuePair<bool, Dictionary<object, object>>(message.main, jsonObject);
                            Debug.Log(string.Format("副表{0}sheet{1}中的{2}替换主表中的内容", message.excelName, dataTable.TableName, id));
                        }
                        else
                        {
                            Debug.LogError("主表中存在相同的ID,或者补丁表中存在相同的ID:" + id);
                        }
                    }
                    else
                    {
                        //列表中记录的为副表内容,当前内容为主表时不做处理
                        if (message.main == false)
                        {
                            Debug.LogError("主表中存在相同的ID,或者补丁表中存在相同的ID:" + id);
                        }
                        else
                        {
                            Debug.Log(string.Format("副表{0}sheet{1}中的{2}替换主表中的内容", message.excelName, dataTable.TableName, id));
                        }
                    }
                }
                else
                {
                    bool main = message.main;
                    resultDic.Add(id, new KeyValuePair<bool, Dictionary<object, object>>(main, jsonObject));
                }
            }
        }
        foreach (var item in resultDic.Values)
        {
            jsonArray.Add(item.Value);
        }
        string relativePath = Path.Combine(buildData.exportResourceDirectory, Name_TableDataSet + FileExtension_Json);
        File.WriteAllText(relativePath, Utf8Json.JsonSerializer.ToJsonString(jsonArray));
    }

    /// <summary>
    /// 更新.asset文件
    /// </summary>
    /// <param name="dataList"></param>
    /// <param name="filePath"></param>
    private static void UpdateTableDataAsset(List<DataTableMessage> dataList)
    {
        //由于编辑器下与运行模式下的程序集不同,因而不能直接使用当前程序集
        Type tableDataType = null;
        Type dataSetType = null;
        Assembly currentAssembly = null;
        //获取脚本所在程序集
        foreach (Assembly item in AppDomain.CurrentDomain.GetAssemblies())
        {
            if (item.GetType(Name_TableData) != null)
            {
                currentAssembly = item;
                break;
            }
        }
        tableDataType = currentAssembly.GetType(Name_TableData);
        dataSetType = currentAssembly.GetType(Name_TableDataSet);

        Dictionary<int, KeyValuePair<bool, object>> tableDataDic = new Dictionary<int, KeyValuePair<bool, object>>();
        FieldInfo[] fieldInfo = tableDataType.GetFields();

        for (int m = 0; m < dataList.Count; m++)
        {
            DataTableMessage message = dataList[m];
            DataTable dataTable = dataList[m].data;
            for (int i = Row_Min; i < dataTable.Rows.Count; i++)
            {
                object tableData = Activator.CreateInstance(tableDataType);
                int id = int.Parse(dataTable.Rows[i][0].ToString());
                for (int j = 0; j < dataTable.Columns.Count; j++)
                {
                    for (int n = 0; n < fieldInfo.Length; n++)
                    {
                        string fieldName = dataTable.Rows[Row_TableDataField_Name][j].ToString();
                        if (string.Equals(fieldInfo[n].Name, fieldName))
                        {
                            try
                            {
                                string type = dataTable.Rows[Row_TableDataField_Type][j].ToString();
                                object value = dataTable.Rows[i][j];
                                if (supportedDataTypes.Contains(type))
                                {
                                    fieldInfo[n].SetValue(tableData, DataSheetPipeline.GetFieldValue(type, value));
                                }
                                else
                                {
                                    Debug.LogError(string.Format("{0}表的第{0}列存在未知的数据类型,请检查", dataTable.TableName, j + 1));
                                }
                                break;
                            }
                            catch (Exception ex)
                            {
                                string error = string.Format("{0}的第{1}行第{2}列存在问题:{3}", dataTable.TableName, i + 1, j + 1, ex);
                            }
                        }
                    }
                }
                if (tableDataDic.ContainsKey(id))
                {
                    //列表中记录的为主表内容,
                    if (tableDataDic[id].Key)
                    {
                        //当前内容为副表，替换
                        if (message.main == false)
                        {
                            tableDataDic[id] = new KeyValuePair<bool, object>(message.main, tableData);
                            Debug.Log(string.Format("副表{0}sheet{1}中的{2}替换主表中的内容", message.excelName, dataTable.TableName, id));
                        }
                        else
                        {
                            Debug.LogError("主表中存在相同的ID,或者补丁表中存在相同的ID:" + id);
                        }
                    }
                    else
                    {
                        //列表中记录的为副表内容,当前内容为主表时不做处理
                        if (message.main == false)
                        {
                            Debug.LogError("主表中存在相同的ID,或者补丁表中存在相同的ID:" + id);
                        }
                        else
                        {
                            Debug.Log(string.Format("副表{0}sheet{1}中的{2}替换主表中的内容", message.excelName, dataTable.TableName, id));
                        }
                    }
                }
                else
                {
                    bool main = message.main;
                    tableDataDic.Add(id, new KeyValuePair<bool, object>(main, tableData));
                }
            }
        }
        string assetPath = Path.Combine(buildData.exportResourceDirectory, Name_TableDataSet + ".asset");
        assetPath = assetPath.Replace(Application.dataPath, "Assets");
        object dataSetAsset = CreateInstance(dataSetType);
        MethodInfo method = dataSetType.GetMethod("SetData");
        List<object> tableDataList = new List<object>();
        foreach (var item in tableDataDic.Values)
        {
            tableDataList.Add(item.Value);
        }
        method.Invoke(dataSetAsset, new object[] { tableDataList.ToArray() });
        AssetDatabase.CreateAsset(dataSetAsset as UnityEngine.Object, assetPath);
    }

    /// <summary>
    /// 将脚本文件拷贝到指定路径
    /// </summary>
    private static void CopyScriptsToSpecifiedPath()
    {
        if (buildData.destScriptDirectory != null)
        {
            if (Directory.Exists(buildData.destScriptDirectory) == false)
            {
                Directory.CreateDirectory(buildData.destScriptDirectory);
            }

            string[] files1 = Directory.GetFiles(buildData.exportScriptDirectory, "*.cs");
            foreach (var item in files1)
            {
                string fileName = Path.GetFileName(item);
                if (fileName == Name_TableData || fileName == Name_TableDataSet)
                {
                    string targetPath = Path.Combine(buildData.destScriptDirectory, fileName);
                    File.Copy(item, targetPath, true);
                }
            }
        }
    }

    private static void GetBuildData()
    {
        string cachePath = Path.Combine(Application.dataPath, Path_PlayerPreferences);
        if (File.Exists(cachePath))
        {
            BinaryFormatter bf = new BinaryFormatter();
            using (FileStream stream = File.Open(cachePath, FileMode.Open))
            {
                if (bf.Deserialize(stream) is TextTableBuildData data)
                {
                    buildData = data;
                }
            }
        }
        else
        {
            buildData = new TextTableBuildData();
        }
    }

    private static void SaveBuildData()
    {
        string cachePath = Path.Combine(Application.dataPath, Path_PlayerPreferences);

        BinaryFormatter bf = new BinaryFormatter();
        using (FileStream stream = File.Create(cachePath))
        {
            bf.Serialize(stream, buildData);
        }
    }

    private void OnEnable()
    {
        GetBuildData();
    }

    private void OnDisable()
    {
        SaveBuildData();
    }

    private void OnGUI()
    {
        EditorGUILayout.Space();
        EditorGUILayout.LabelField(string.Format("1.文本表目录:{0}", buildData.textDataDirectory));
        if (string.IsNullOrEmpty(buildData.textDataDirectory))
        {
            GUILayout.Label(new GUIContent("文本表目录为空", EditorGUIUtility.FindTexture("console.erroricon")));
        }

        if (GUILayout.Button("选择导入文本表目录"))
        {
            if (string.IsNullOrEmpty(buildData.textDataDirectory))
            {
                buildData.textDataDirectory = Path.GetFullPath(".");
            }
            string selectPath = EditorUtility.OpenFolderPanel("选择导入文本表目录", buildData.textDataDirectory, "");
            buildData.textDataDirectory = selectPath;
            Repaint();
        }
        EditorGUILayout.Space();


        EditorGUILayout.LabelField(string.Format("2.脚本导出目录:{0}", buildData.exportScriptDirectory));
        if (string.IsNullOrEmpty(buildData.exportScriptDirectory))
        {
            GUILayout.Label(new GUIContent("脚本导出目录为空", EditorGUIUtility.FindTexture("console.erroricon")));
        }

        if (GUILayout.Button("选择脚本导出目录"))
        {
            if (string.IsNullOrEmpty(buildData.exportScriptDirectory))
            {
                buildData.exportScriptDirectory = Path.GetFullPath(".");
            }
            string selectPath = EditorUtility.OpenFolderPanel("选择导出脚本文件目录", buildData.exportScriptDirectory, "");
            buildData.exportScriptDirectory = selectPath;
            Repaint();
        }

        EditorGUILayout.LabelField(string.Format("3.资源导出目录:{0}", buildData.exportResourceDirectory));
        if (string.IsNullOrEmpty(buildData.exportResourceDirectory))
        {
            GUILayout.Label(new GUIContent("资源导出目录为空", EditorGUIUtility.FindTexture("console.erroricon")));
        }

        if (GUILayout.Button("选择资源导出目录"))
        {
            if (string.IsNullOrEmpty(buildData.exportResourceDirectory))
            {
                buildData.exportResourceDirectory = Path.GetFullPath(".");
            }
            string selectPath = EditorUtility.OpenFolderPanel("选择导出Json文件目录", buildData.exportResourceDirectory, "");
            buildData.exportResourceDirectory = selectPath;
            Repaint();
        }
        EditorGUILayout.Space();

        GUIContent forceContent = new GUIContent("3.是否将脚本拷贝至其他目录");
        bool forceCurrent = EditorGUILayout.ToggleLeft(forceContent, buildData.copy);
        buildData.copy = forceCurrent;

        if (buildData.copy)
        {
            EditorGUILayout.LabelField(string.Format("脚本拷贝目录:{0}", buildData.destScriptDirectory));

            if (GUILayout.Button("选择脚本拷贝目录"))
            {
                if (string.IsNullOrEmpty(buildData.destScriptDirectory))
                {
                    buildData.destScriptDirectory = Path.GetFullPath(".");
                }
                string selectPath = EditorUtility.OpenFolderPanel("选择脚本拷贝目录", buildData.destScriptDirectory, "");
                buildData.destScriptDirectory = selectPath;
                Repaint();
            }
        }

        EditorGUILayout.Space();
        EditorGUILayout.Space();

        if (GUILayout.Button("开始更新文本表"))
        {
            if (string.IsNullOrEmpty(buildData.textDataDirectory))
            {
                ShowNotification(new GUIContent("excel文件目录为空,无法更新！"));
            }
            else if (string.IsNullOrEmpty(buildData.exportScriptDirectory))
            {
                ShowNotification(new GUIContent("脚本文件目录为空,无法更新！"));
            }
            else if (string.IsNullOrEmpty(buildData.exportResourceDirectory))
            {
                ShowNotification(new GUIContent("资源文件目录为空,无法更新！"));
            }
            else
            {
                switch (buildData.format)
                {
                    case DataFormatEnum.Asset:
                        UpdateTextTableToAsset();
                        break;
                    case DataFormatEnum.Json:
                        UpdateTextTableToJosn();
                        break;
                    default:
                        break;
                }
                Close();
            }
        }
    }

    #endregion

    [Serializable]
    public class TextTableBuildData
    {
        public string textDataDirectory;
        public string exportScriptDirectory;
        public string exportResourceDirectory;
        public bool copy;
        public string destScriptDirectory;
        public bool updating;
        public DataFormatEnum format;
    }
}