/**
* UnityVersion: 2019.3.15f1
* FileName:     DataSheetPipeline.cs
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
using Utf8Json;

public enum DataFormatEnum
{
    Asset = 1,
    Json,
}

public class DataSheetPipeline : EditorWindow
{
    #region 通用
    private const string Directory_Default_Scripts = "Assets/Scripts/Common/DataPipeline/CustemDataType";
    private const string Directory_Output = "../../../../output/";
    private const string TemplateDirectory_Common = "Assets/Scripts/Common/DataPipeline/ScriptTemplate/";
    private const string Path_PlayerPreferences = "../Library/DataSheetBuildData.dat";

    private static readonly string[] Special_Characters = new string[] { "(", ")", "[", "]", "{", "}" };
    private static readonly char[] Common_Separators = new char[] { '|', ',' };
    //支持的数据类型
    private static List<string> supportedDataTypes = new List<string>()
    {
        "int","long","float","double","bool","string", "Vector2","Vector3", "Article","Range",
        "int[]","long[]","float[]","double[]","bool[]","string[]","Vector2[]","Vector3[]","Article[]","Range[]"
    };
    //前4行定义(前四行有特殊含义,不是表示数据位)
    private const int Row_Min = 5;
    private const int Row_TableData_Describe = 0;
    private const int Row_TableDataField_Describe = 1;
    private const int Row_TableDataField_Name = 2;
    private const int Row_TableDataField_Type = 4;


    private const string FileExtension_Cs = ".cs";

    //模板文件
    private const string TableDataMgr_FileName = "TableDataMgr.cs";
    private const string TemplateFile_TableDataField = "TableDataField.txt";
    private const string TemplateFile_TableData = "TableData.txt";
    private const string TemplateFile_DataSet = "DataSet.txt";
    private const string TemplateFile_TableDataMgr = "TableDataMgr.txt";
    private const string TemplateFile_TableDataMgrEvent = "TableDataMgrEvent.txt";
    private const string TemplateFile_TableDataMgrField = "TableDataMgrField.txt";
    private const string TemplateFile_TableDataMgrPrivateMethod = "TableDataMgrPrivateMethod.txt";
    private const string TemplateFile_TableDataMgrPublicMethod = "TableDataMgrPublicMethod.txt";

    private const string FieldName = "#FieldName#";
    private const string TableDataName = "#TableDataName#";
    private const string DataSetName = "#DataSetName#";

    #endregion

    #region Asset相关
    private const string TemplateDirectory_Asset = "Assets/Scripts/Common/DataPipeline/ScriptTemplate/AssetTemplate/";
    private const string File_LocalCacheMD5_Asset = "LocalCacheMD5_Asset.txt";
    private const string FileExtension_Asset = ".asset";
    #endregion

    #region Json相关
    private const string TemplateDirectory_Json = "Assets/Scripts/Common/DataPipeline/ScriptTemplate/JsonTemplate/";
    private const string File_LocalCacheMD5_Json = "LocalCacheMD5_Json.txt";
    private const string FileExtension_Json = ".txt";
    #endregion

    /// <summary>
    /// 更新数据表方式(增\删\改)
    /// </summary>
    private enum UpdateDataSheetMode
    {
        None,
        Add,
        Delete,
        Change
    }

    private static DataSheetBuildData buildData;

    private static Dictionary<string, UpdateDataSheetMode> updateDic = new Dictionary<string, UpdateDataSheetMode>();
    private static Dictionary<string, DataTable> dataTableDic = new Dictionary<string, DataTable>();
    private static Dictionary<string, string> newMD5Dic = new Dictionary<string, string>();
    private static Dictionary<string, string> oldMD5Dic = new Dictionary<string, string>();
    private static List<string> excelPaths = new List<string>();

    #region Public Method

    public static void ShowAssetEditorWindow()
    {
        DataSheetPipeline window = (DataSheetPipeline)GetWindow(typeof(DataSheetPipeline), false, "数据表生产线（Asset）", true);
        window.Show();
        buildData.format = DataFormatEnum.Asset;
    }

    [MenuItem("Tools/2.导入表格数据", false, 2)]
    public static void ShowJsonEditorWindow()
    {
        DataSheetPipeline window = (DataSheetPipeline)GetWindow(typeof(DataSheetPipeline), false, "数据生产线（Json）", true);
        window.Show();
        buildData.format = DataFormatEnum.Json;
    }

    /// <summary>
    /// 命令行调用更新数据表（Asset模式）
    /// </summary>
    public static void UpdateDataSheetToAssetWithCMD()
    {
        GetParametersFromCommandLine();
        UpdateDataSheetToAsset();
    }

    /// <summary>
    /// 命令行调用更新数据表（Json模式）
    /// </summary>
    public static void UpdateDataSheetToJosnWithCMD()
    {
        GetParametersFromCommandLine();
        UpdateDataSheetToJosn();
    }

    /// <summary>
    /// 在数据生产线生产过程中会伴随这代码编译,再编译过程中所有的变量都会重新初始化,函数也无法执行,并且后面
    /// 函数中需要用到前面编译的脚本,因此先进行编译,等编译完成后再执行后面的代码.
    /// </summary>
    public static void OnScriptsReload()
    {
        LoadBuildData();
        if (buildData.updating && buildData.format == DataFormatEnum.Asset)
        {
            buildData.updating = false;
            SaveBuildData();
            OnScriptReload_Asset();
        }
    }

    #endregion

    #region Private Method

    /// <summary>
    /// 更新数据表文件为Json
    /// </summary>
    private static void UpdateDataSheetToJosn()
    {
        Utf8jsonHelper.EditorInitialize();
        Debug.Log("1.开始更新数据表");
        AssetPostProcessMgr.enabled = false;
        Debug.Log("2.读取本地数据表,并得到需要更新的表");
        GenerateData();
        Debug.Log("5.更新..tableData.cs文件与..DataSet.cs文件");
        if (Directory.Exists(buildData.exportScriptDirectory) == false)
        {
            Directory.CreateDirectory(buildData.exportScriptDirectory);
        }
        foreach (var item in updateDic)
        {
            if (item.Value == UpdateDataSheetMode.Change || item.Value == UpdateDataSheetMode.Add)
            {
                UpdateTableDataScript(dataTableDic[item.Key]);
                UpdateDataSetScript(dataTableDic[item.Key], TemplateDirectory_Json);
            }
            else
            {
                string tableDataFileName = GetTableDataName(item.Key) + FileExtension_Cs;
                string tableDataFilePath = Path.Combine(buildData.exportScriptDirectory, tableDataFileName);
                DeleteFile(tableDataFilePath);

                string dataSetFileName = GetDataSetName(item.Key) + FileExtension_Cs;
                string dataSetFilePath = Path.Combine(buildData.exportScriptDirectory, dataSetFileName);
                DeleteFile(dataSetFilePath);
            }
        }
        Debug.Log("6.更新TableDataMgr.cs文件");
        UpdateTableDataMgrScript(dataTableDic, TemplateDirectory_Json);
        Debug.Log("7.更新Json文件");
        if (Directory.Exists(buildData.exportResourceDirectory) == false)
        {
            Directory.CreateDirectory(buildData.exportResourceDirectory);
        }
        foreach (var item in updateDic)
        {
            if (item.Value == UpdateDataSheetMode.Change || item.Value == UpdateDataSheetMode.Add)
            {
                UpdateTableDataJson(dataTableDic[item.Key], item.Key);
            }
            else
            {
                string fileName = GetDataSetName(item.Key) + FileExtension_Json;
                string filePath = Path.Combine(buildData.exportResourceDirectory, fileName);
                DeleteFile(filePath);
            }
        }
        if (buildData.copy)
        {
            Debug.Log("8.复制脚本文件到指定路径：" + buildData.destScriptDirectory);
            CopyScriptsToSpecifiedPath();
        }
        Debug.Log("9.更新本地缓存的MD5文件");
        UpdateDataSheetMD5(File_LocalCacheMD5_Json);
        AssetPostProcessMgr.enabled = true;
        AssetDatabase.Refresh();
        Debug.Log("更新数据表完成!,请进入游戏查看");
    }

    /// <summary>
    /// 更新数据表文件为Asset资源
    /// </summary>
    private static void UpdateDataSheetToAsset()
    {
        Debug.Log("1.开始更新数据表");
        buildData.updating = true;
        AssetPostProcessMgr.enabled = false;
        Debug.Log("2.读取本地数据表,并得到需要更新的表");
        GenerateData();
        Debug.Log("5.更新..TableData.cs文件与..DataSet.cs文件");
        if (Directory.Exists(buildData.exportScriptDirectory) == false)
        {
            Directory.CreateDirectory(buildData.exportScriptDirectory);
        }
        foreach (var item in updateDic)
        {
            if (item.Value == UpdateDataSheetMode.Change || item.Value == UpdateDataSheetMode.Add)
            {
                UpdateTableDataScript(dataTableDic[item.Key]);
                UpdateDataSetScript(dataTableDic[item.Key], TemplateDirectory_Asset);
            }
            else
            {
                string tableDataFileName = GetTableDataName(item.Key) + FileExtension_Cs;
                string tableDataFilePath = Path.Combine(buildData.exportScriptDirectory, tableDataFileName);

                string dataSetFileName = GetDataSetName(item.Key) + FileExtension_Cs;
                string dataSetFilePath = Path.Combine(buildData.exportScriptDirectory, dataSetFileName);

                DeleteFile(tableDataFilePath);
                DeleteFile(dataSetFilePath);
            }
        }
        Debug.Log("6.更新TableDataMgr.cs文件,并编译脚本");
        UpdateTableDataMgrScript(dataTableDic, TemplateDirectory_Asset);
        if (Directory.Exists(buildData.exportResourceDirectory) == false)
        {
            Directory.CreateDirectory(buildData.exportResourceDirectory);
        }
        SaveBuildData();
        AssetPostProcessMgr.enabled = true;
        AssetDatabase.Refresh();
        //产生编译行为，那么静态变量重新初始化,需要等编译完成之后重新获取数据;如果没有产生编译那么就继续执行
        if (EditorApplication.isCompiling == false)
        {
            buildData.updating = false;
            SaveBuildData();
            Debug.Log("7.未产生编译行为,脚本内容没有变更,直接更新.asset文件");
            foreach (var item in updateDic)
            {
                if (item.Value == UpdateDataSheetMode.Change || item.Value == UpdateDataSheetMode.Add)
                {
                    UpdateTableDataAsset(dataTableDic[item.Key], item.Key);
                }
                else
                {
                    string fileName = GetDataSetName(item.Key) + FileExtension_Asset;
                    string filePath = Path.Combine(buildData.exportResourceDirectory, fileName);
                    DeleteFile(filePath);
                }
            }
            Debug.Log("8.脚本内容未变更,不拷贝到指定路径,直接更新本地MD5文件");
            UpdateDataSheetMD5(File_LocalCacheMD5_Asset);
            AssetPostProcessMgr.enabled = true;
            AssetDatabase.Refresh();
            Debug.Log("更新数据表完成.");
        }
        else
        {
            Debug.Log("7.发生了编译行为,脚本内容发生变更,缓存本地数据待脚本编译完成后重新执行");
        }
    }

    /// <summary>
    /// 从命令行获取参数设置路径
    /// </summary>
    private static void GetParametersFromCommandLine()
    {
        buildData = new DataSheetBuildData();
        string[] args = System.Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == nameof(buildData.dataSheetDirectory))
            {
                buildData.dataSheetDirectory = args[i + 1];
                Debug.Log("从命令行获取参数并设置数据表路径为：" + buildData.dataSheetDirectory);
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
            else if (args[i] == nameof(buildData.force))
            {
                buildData.force = bool.Parse(args[i + 1]);
                Debug.Log("从命令行获取参数并设置是否强制刷新为：" + buildData.force);
            }
        }
    }

    /// <summary>
    /// 生成数据
    /// </summary>
    private static void GenerateData()
    {
        GetAllTableDataPaths();
        ConvertExcelToDataTable();
        GetTheLocalCacheDataSheetMD5();
        GetDataSheetThatNeedsToUpdate();
    }

    /// <summary>
    /// 获取所有表数据文件路径
    /// </summary>
    /// <returns></returns>
    private static void GetAllTableDataPaths()
    {
        excelPaths.Clear();
        string[] files = Directory.GetFiles(buildData.dataSheetDirectory);
        for (int i = 0; i < files.Length; i++)
        {
            string fileName = files[i].Replace("\\", "/");
            if ((fileName.EndsWith(".xls") || fileName.EndsWith(".xlsx") || fileName.EndsWith(".xlsm")) && fileName.Contains("~$") == false)
            {
                excelPaths.Add(fileName);
            }
        }
        excelPaths.Sort((a, b) => a.CompareTo(b));
        if (excelPaths.Count <= 0)
        {
            Debug.Log(string.Format("在{0}路径下未找到Excel文件,请检查", buildData.dataSheetDirectory));
        }
    }

    /// <summary>
    /// 获取本地缓存的数据表MD5值
    /// </summary>
    /// <returns></returns>
    private static void GetTheLocalCacheDataSheetMD5()
    {
        oldMD5Dic.Clear();
        if (buildData.force == false)
        {
            string localMd5Path = "";
            switch (buildData.format)
            {
                case DataFormatEnum.Asset:
                    localMd5Path = File_LocalCacheMD5_Asset;
                    break;
                case DataFormatEnum.Json:
                    localMd5Path = File_LocalCacheMD5_Json;
                    break;
                default:
                    break;
            }
            string outputDirectoryPath = Path.Combine(Path.GetFullPath("."), Directory_Output);
            string filePath = Path.Combine(outputDirectoryPath, localMd5Path);
            if (File.Exists(filePath))
            {
                string[] content = File.ReadAllLines(filePath);
                for (int i = 0; i < content.Length; i++)
                {
                    if (string.IsNullOrEmpty(content[i]) == false)
                    {
                        string[] splitArray = content[i].Split('|');
                        oldMD5Dic.Add(splitArray[0], splitArray[1]);
                    }
                    else
                    {
                        Debug.LogError(string.Format("本地缓存的数据表MD5第{0}行为空，请检查路径{1}", i + 1, filePath));
                        throw new UnityException();
                    }
                }
            }
        }
    }

    /// <summary>
    /// 获取发生改变的数据表
    /// </summary>
    /// <param name="oldMD5Dic">旧的MD5</param>
    /// <param name="newMD5Dic">新的MD5</param>
    /// <returns><路径，更新方式></returns>
    private static void GetDataSheetThatNeedsToUpdate()
    {
        updateDic.Clear();
        foreach (var item in newMD5Dic)
        {
            //相同的数据表
            if (oldMD5Dic.ContainsKey(item.Key))
            {
                //MD5值不相等,则认定此表有改动
                if (string.Equals(item.Value, oldMD5Dic[item.Key]) == false)
                {
                    updateDic.Add(item.Key, UpdateDataSheetMode.Change);
                    Debug.Log(string.Format("{0}需要更新(修改)", item.Key));
                }
            }
            //新增的表(无条件更新)
            else
            {
                updateDic.Add(item.Key, UpdateDataSheetMode.Add);
                Debug.Log(string.Format("{0}需要更新(新增)", item.Key));
            }
        }

        //已经被删除的表
        foreach (var item in oldMD5Dic)
        {
            if (newMD5Dic.ContainsKey(item.Key) == false)
            {
                updateDic.Add(item.Key, UpdateDataSheetMode.Delete);
                Debug.Log(string.Format("{0}需要更新(删除)", item.Key));
            }
        }
        if (updateDic.Count <= 0)
        {
            Debug.Log("无数据表发生变更!");
        }
    }

    /// <summary>
    /// 读取数据表中所有符合条件的Sheet并将里面的数据转换为DataTable,并计算每一个Sheet的MD5值
    /// </summary>
    /// <param name="excelPath"></param>
    /// <returns></returns>
    private static void ConvertExcelToDataTable()
    {
        dataTableDic.Clear();
        newMD5Dic.Clear();
        foreach (var onePath in excelPaths)
        {
            try
            {
                FileStream excelStream = File.OpenRead(onePath);
                IExcelDataReader excelReader = ExcelReaderFactory.CreateOpenXmlReader(excelStream);
                DataSet data = excelReader.AsDataSet();
                System.Security.Cryptography.MD5 md5Computer = new System.Security.Cryptography.MD5CryptoServiceProvider();
                byte[] md5Array = md5Computer.ComputeHash(excelStream);
                string md5 = BitConverter.ToString(md5Array);
                excelStream.Dispose();
                excelStream.Close();
                for (int i = 0; i < data.Tables.Count; i++)
                {
                    DataTable item = data.Tables[i];
                    //由英文与数字、下划线构成TableName表，，认为是需要的
                    if (item.TableName.StartsWith("#") == false)
                    {
                        if (item.Rows.Count > Row_Min && item.Columns.Count > 0)
                        {
                            if (dataTableDic.ContainsKey(item.TableName))
                            {
                                Debug.LogError("重复加入:" + onePath + item.TableName);
                                throw new UnityException();
                            }
                            //将数据表中的每一个Sheet由DataTable转成byte[]并计算MD5值
                            dataTableDic.Add(item.TableName, item);
                            newMD5Dic.Add(item.TableName, md5);
                        }
                        else
                        {
                            Debug.LogError(string.Format("{0}表中的Sheet:{0}存在格式问题,行数或列数低于最小限制", onePath, item.TableName));
                            throw new UnityException();
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
    /// 更新TableData.cs脚本
    /// </summary>
    /// <param name="data">数据</param>
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
                fieldContent.Append(string.Format(fieldTemplate.text, fieldDescribe, fieldType, fieldName));
            }
        }

        //获取TableData模板文件并填充表名与字段,创建出TableData.cs脚本
        string describe = data.Rows[Row_TableData_Describe][0].ToString();
        string name = GetTableDataName(data.TableName);
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
        string tableDataName = GetTableDataName(data.TableName);
        string dataSetName = GetDataSetName(data.TableName);
        string templatePath = Path.Combine(directory, TemplateFile_DataSet);
        TextAsset template = AssetDatabase.LoadAssetAtPath(templatePath, typeof(TextAsset)) as TextAsset;
        string content = template.text;
        content = content.Replace(DataSetName, dataSetName);
        content = content.Replace(TableDataName, tableDataName);
        string exprotFilePath = Path.Combine(buildData.exportScriptDirectory, dataSetName + FileExtension_Cs);
        File.WriteAllText(exprotFilePath, content, new UTF8Encoding(true));
    }

    private static void OnScriptReload_Asset()
    {
        Debug.Log("8.脚本编译完成,重新获取数据");
        AssetPostProcessMgr.enabled = false;
        GenerateData();
        Debug.Log("9.更新.asset文件");
        foreach (var item in updateDic)
        {
            if (item.Value == UpdateDataSheetMode.Change || item.Value == UpdateDataSheetMode.Add)
            {
                UpdateTableDataAsset(dataTableDic[item.Key], item.Key);
            }
            else
            {
                string fileName = GetDataSetName(item.Key) + FileExtension_Asset;
                string filePath = Path.Combine(buildData.exportResourceDirectory, fileName);
                DeleteFile(filePath);
            }
        }
        if (buildData.copy)
        {
            Debug.Log("10.复制脚本文件到指定路径：" + buildData.destScriptDirectory);
            CopyScriptsToSpecifiedPath();
        }
        Debug.Log("11.更新本地缓存MD5文件");
        UpdateDataSheetMD5(File_LocalCacheMD5_Asset);
        AssetPostProcessMgr.enabled = true;
        AssetDatabase.Refresh();

        Debug.Log("12.更新数据表完成!请进入游戏查看");
    }

    /// <summary>
    /// 更新TableDataMgr.cs脚本
    /// </summary>
    /// <param name="data">数据</param>
    /// <param name="directory">模板目录(区分出Asset和Json)</param>
    private static void UpdateTableDataMgrScript(Dictionary<string, DataTable> data, string directory)
    {
        string eventPath = Path.Combine(directory, TemplateFile_TableDataMgrEvent);
        string eventContent = (AssetDatabase.LoadAssetAtPath(eventPath, typeof(TextAsset)) as TextAsset).text;

        StringBuilder fieldContent = new StringBuilder();
        StringBuilder privateMethodContent = new StringBuilder();
        StringBuilder publicMethodContent = new StringBuilder();
        StringBuilder loadMethodContent = new StringBuilder();
        foreach (var item in data.Values)
        {
            string fieldPath = Path.Combine(TemplateDirectory_Common, TemplateFile_TableDataMgrField);
            fieldContent.Append(GetTableDataMgrContent(fieldPath, item));

            string loadMethod = string.Format("        Check{0}();", GetTableDataName(item.TableName));
            loadMethodContent.AppendLine(loadMethod);

            string publicMethodPath = Path.Combine(TemplateDirectory_Common, TemplateFile_TableDataMgrPublicMethod);
            publicMethodContent.Append(GetTableDataMgrContent(publicMethodPath, item));

            string privateMethodPath = Path.Combine(directory, TemplateFile_TableDataMgrPrivateMethod);
            privateMethodContent.Append(GetTableDataMgrContent(privateMethodPath, item));
        }
        string path = Path.Combine(TemplateDirectory_Common, TemplateFile_TableDataMgr);
        string template = (AssetDatabase.LoadAssetAtPath(path, typeof(TextAsset)) as TextAsset).text;
        string content = string.Format(template, eventContent, fieldContent.ToString(),
            loadMethodContent, publicMethodContent.ToString(), privateMethodContent.ToString());

        string scriptPath = Path.Combine(buildData.exportScriptDirectory, TableDataMgr_FileName);
        File.WriteAllText(scriptPath, content);
    }

    /// <summary>
    /// 更新.asset文件
    /// </summary>
    /// <param name="data"></param>
    /// <param name="filePath"></param>
    private static void UpdateTableDataAsset(DataTable data, string filePath)
    {
        string fileName = Path.GetFileName(filePath);
        //由于编辑器下与运行模式下的程序集不同,因而不能直接使用当前程序集
        Type tableDataType = null;
        Type dataSetType = null;
        Assembly currentAssembly = null;
        //获取脚本所在程序集
        foreach (Assembly item in AppDomain.CurrentDomain.GetAssemblies())
        {
            if (item.GetType(GetTableDataName(data.TableName)) != null)
            {
                currentAssembly = item;
                break;
            }
        }
        tableDataType = currentAssembly.GetType(GetTableDataName(data.TableName));
        dataSetType = currentAssembly.GetType(GetDataSetName(data.TableName));

        List<object> tableDataList = new List<object>();
        FieldInfo[] fieldInfo = tableDataType.GetFields();
        for (int i = Row_Min; i < data.Rows.Count; i++)
        {
            object tableData = Activator.CreateInstance(tableDataType);
            for (int j = 0; j < data.Columns.Count; j++)
            {
                for (int m = 0; m < fieldInfo.Length; m++)
                {
                    string fieldName = data.Rows[Row_TableDataField_Name][j].ToString();
                    if (string.Equals(fieldInfo[m].Name, fieldName))
                    {
                        try
                        {
                            string type = data.Rows[Row_TableDataField_Type][j].ToString();
                            object value = data.Rows[i][j];
                            if (supportedDataTypes.Contains(type))
                            {
                                fieldInfo[m].SetValue(tableData, GetFieldValue(type, value));
                            }
                            else
                            {
                                Debug.LogError(string.Format("{0}表的第{0}列存在未知的数据类型,请检查", fileName, j + 1));
                                throw new UnityException();
                            }
                            break;
                        }
                        catch (Exception ex)
                        {
                            Debug.Log(string.Format("{0}的第{1}行第{2}列存在问题:{3}", fileName, i + 1, j + 1, ex));
                            throw new UnityException();
                        }
                    }
                }
            }
            tableDataList.Add(tableData);
        }
        string assetPath = Path.Combine(buildData.exportResourceDirectory, GetDataSetName(data.TableName) + ".asset");
        object dataSetAsset = Editor.CreateInstance(dataSetType);
        MethodInfo method = dataSetType.GetMethod("SetData");
        method.Invoke(dataSetAsset, new object[] { tableDataList.ToArray() });
        AssetDatabase.CreateAsset(dataSetAsset as UnityEngine.Object, assetPath);
    }

    /// <summary>
    /// 更新.json文件
    /// </summary>
    private static void UpdateTableDataJson(DataTable data, string filePath)
    {
        string fileName = Path.GetFileName(filePath);
        List<Dictionary<object, object>> jsonArray = new List<Dictionary<object, object>>();
        for (int i = Row_Min; i < data.Rows.Count; i++)
        {
            Dictionary<object, object> jsonObject = new Dictionary<object, object>();
            for (int j = 0; j < data.Columns.Count; j++)
            {
                if (data.Rows[Row_TableDataField_Describe][j].ToString().StartsWith("#") == false)
                {
                    string type = data.Rows[Row_TableDataField_Type][j].ToString();
                    if (supportedDataTypes.Contains(type))
                    {
                        string key = data.Rows[Row_TableDataField_Name][j].ToString();
                        try
                        {
                            object value = GetFieldValue(type, data.Rows[i][j]);
                            jsonObject.Add(key, value);
                        }
                        catch (Exception e)
                        {
                            Debug.LogError(string.Format("{0}表的第{1}行第{2}列解析错误,请检查！错误内容：{3}", filePath, i + 1, j + 1, e));
                            throw new UnityException();
                        }
                    }
                    else
                    {
                        Debug.LogError(string.Format("{0}表的第{1}列是未知的数据类型-{2}-,请检查", fileName, j + 1, type));
                        throw new UnityException();
                    }
                }
            }
            jsonArray.Add(jsonObject);
        }
        string relativePath = Path.Combine(buildData.exportResourceDirectory, GetDataSetName(data.TableName) + FileExtension_Json);
        string absolutePath = Path.GetFullPath(Path.Combine(Path.GetFullPath("."), relativePath));
        File.WriteAllText(absolutePath, JsonSerializer.ToJsonString(jsonArray));
    }

    /// <summary>
    /// 删除文件(包括.meta文件)
    /// </summary>
    /// <param name="filePath"></param>
    private static void DeleteFile(string filePath)
    {
        string jsontMetaPath = filePath + ".meta";
        if (File.Exists(filePath))
        {
            File.Delete(filePath);
            File.Delete(jsontMetaPath);
        }
        else
        {
            Debug.LogError(string.Format("需要删除的文件({0})已经不存在了,请检查", filePath));
        }
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
                string targetPath = Path.Combine(buildData.destScriptDirectory, fileName);
                File.Copy(item, targetPath, true);
            }

            string[] files2 = Directory.GetFiles(Directory_Default_Scripts, "*.cs");
            foreach (var item in files2)
            {
                string fileName = Path.GetFileName(item);
                string targetPath = Path.Combine(buildData.destScriptDirectory, fileName);
                File.Copy(item, targetPath, true);
            }
        }
    }

    /// <summary>
    /// 更新数据表的MD5值（用以校验数据表是否更新）
    /// </summary>
    /// <param name="path">保存路径</param>
    /// <param name="md5Dic">保存内容</param>
    private static void UpdateDataSheetMD5(string fileName)
    {
        if (Directory.Exists(Directory_Output) == false)
        {
            Directory.CreateDirectory(Directory_Output);
        }

        StringBuilder content = new StringBuilder();
        foreach (var item in newMD5Dic)
        {
            content.Append(string.Concat(item.Key, "|", item.Value));
            content.AppendLine();
        }
        string cachePath = Path.Combine(Directory_Output, fileName);
        File.WriteAllText(cachePath, content.ToString());
    }

    private static string GetTableDataName(string dataName)
    {
        return dataName + "TableData";
    }

    private static string GetDataSetName(string dataName)
    {
        return dataName + "DataSet";
    }

    private static string GetTableDataMgrContent(string path, DataTable data)
    {
        string result = "";
        string content = (AssetDatabase.LoadAssetAtPath(path, typeof(TextAsset)) as TextAsset).text;
        string dataSetName = GetDataSetName(data.TableName);
        string tableDataName = GetTableDataName(data.TableName);
        string fieldName = data.TableName.Substring(0, 1).ToLower() + data.TableName.Substring(1) + "Data";
        result = content.Replace(TableDataName, tableDataName);
        result = result.Replace(DataSetName, dataSetName);
        result = result.Replace(FieldName, fieldName);
        return result;
    }

    public static object GetFieldValue(string type, object value)
    {
        object result = null;
        string current = value.ToString();
        if (string.IsNullOrEmpty(current) == false)
        {
            if (type != "string")
            {
                //type为Article[]数组时，自行解析，无需要这里做处理
                if (type != "Article[]")
                {
                    for (int i = 0; i < Special_Characters.Length; i++)
                    {
                        current = current.Replace(Special_Characters[i], "");
                    }
                }
            }
            current = current.Trim();
        }

        if (type == "int")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = 0;
            }
            else
            {
                result = int.Parse(current);
            }
        }
        else if (type == "long")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = 0;
            }
            else
            {
                result = ulong.Parse(current);
            }
        }
        else if (type == "float")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = 0;
            }
            else
            {
                result = float.Parse(current);
            }
        }
        else if (type == "double")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = 0;
            }
            else
            {
                result = double.Parse(current);
            }
        }
        else if (type == "bool")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = false;
            }
            else
            {
                result = Convert.ToBoolean(int.Parse(current));
            }
        }
        else if (type == "string")
        {
            result = current;
        }
        else if (type == "int[]" || type == "long[]" || type == "float[]" || type == "double[]" ||
            type == "bool[]" || type == "string[]")
        {
            string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
            if (type == "int[]")
            {
                result = Array.ConvertAll(stringArray, s => int.Parse(s));
            }
            else if (type == "long[]")
            {
                result = Array.ConvertAll(stringArray, s => long.Parse(s));
            }
            else if (type == "float[]")
            {
                result = Array.ConvertAll(stringArray, s => float.Parse(s));
            }
            else if (type == "double[]")
            {
                result = Array.ConvertAll(stringArray, s => double.Parse(s));
            }
            else if (type == "bool[]")
            {
                int[] target = Array.ConvertAll(stringArray, s => int.Parse(s));
                result = Array.ConvertAll(target, s => Convert.ToBoolean(s));

            }
            else if (type == "string[]")
            {
                result = stringArray;
            }
        }
        else if (type == "Vector2")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = Vector2.zero;
            }
            else
            {
                string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
                result = new Vector2(float.Parse(stringArray[0]), float.Parse(stringArray[1]));
            }
        }
        else if (type == "Vector2[]")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = null;
            }
            else
            {
                string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
                Vector2[] target = new Vector2[stringArray.Length / 2];
                for (int i = 0; i < target.Length; i++)
                {
                    target[i] = new Vector2(float.Parse(stringArray[i * 2]), float.Parse(stringArray[i * 2 + 1]));
                }
                result = target;
            }
        }
        else if (type == "Vector3")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = Vector3.zero;
            }
            else
            {
                string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
                result = new Vector3(float.Parse(stringArray[0]), float.Parse(stringArray[1]), float.Parse(stringArray[2]));
            }
        }
        else if (type == "Vector3[]")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = null;
            }
            else
            {
                string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
                Vector3[] target = new Vector3[stringArray.Length / 3];
                for (int i = 0; i < target.Length; i++)
                {
                    target[i] = new Vector3(float.Parse(stringArray[i * 3]), float.Parse(stringArray[i * 3 + 1]), float.Parse(stringArray[i * 3 + 2]));
                }
                result = target;
            }
        }
        else if (type == "Article")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = null;
            }
            else
            {
                string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
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

                result = article;
            }
        }
        else if (type == "Range")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = null;
            }
            else
            {
                string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
                float[] floatArray = Array.ConvertAll(stringArray, s => float.Parse(s));
                Range range = new Range
                {
                    min = floatArray[0],
                    max = floatArray[1]
                };
                result = range;
            }
        }
        else if (type == "Article[]")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = null;
            }
            else
            {
/*                string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
                Article[] articleArray = new Article[stringArray.Length / 2];
                for (int i = 0; i < articleArray.Length; i++)
                {
                    articleArray[i] = new Article();
                    articleArray[i].id = int.Parse(stringArray[i * 2]);
                    articleArray[i].count = int.Parse(stringArray[i * 2 + 1]);
                }
                result = articleArray;*/
                result = Article.ParseToArticleArr(current);
                //Debug.Log(result);
            }
        }
        else if (type == "Range[]")
        {
            if (string.IsNullOrEmpty(current))
            {
                result = null;
            }
            else
            {
                string[] stringArray = current.Split(Common_Separators, StringSplitOptions.RemoveEmptyEntries);
                Range[] articleArray = new Range[stringArray.Length / 2];
                for (int i = 0; i < articleArray.Length; i++)
                {
                    articleArray[i] = new Range
                    {
                        min = int.Parse(stringArray[i * 2]),
                        max = int.Parse(stringArray[i * 2 + 1])
                    };
                }
                result = articleArray;
            }
        }
        else
        {
            Debug.LogError(string.Format("支持类型{0},但未写代码", type));
            throw new UnityException();
        }
        return result;
    }

    private static void LoadBuildData()
    {
        string cachePath = Path.Combine(Application.dataPath, Path_PlayerPreferences);
        if (File.Exists(cachePath))
        {
            BinaryFormatter bf = new BinaryFormatter();
            using (FileStream stream = File.Open(cachePath, FileMode.Open))
            {
                if (bf.Deserialize(stream) is DataSheetBuildData data)
                {
                    buildData = data;
                }
            }
        }
        else
        {
            buildData = new DataSheetBuildData();
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

    private void OnGUI()
    {
        EditorGUILayout.Space();
        EditorGUILayout.LabelField(string.Format("1.数据表目录:{0}", buildData.dataSheetDirectory));
        if (string.IsNullOrEmpty(buildData.dataSheetDirectory))
        {
            GUILayout.Label(new GUIContent("数据表目录为空", EditorGUIUtility.FindTexture("console.erroricon")));
        }

        if (GUILayout.Button("选择导入Excel文件目录"))
        {
            if (string.IsNullOrEmpty(buildData.dataSheetDirectory))
            {
                buildData.dataSheetDirectory = Path.GetFullPath(".");
            }
            string selectPath = EditorUtility.OpenFolderPanel("选择导入数据表文件目录", buildData.dataSheetDirectory, "");
            buildData.dataSheetDirectory = selectPath;
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
            string selectPath = EditorUtility.OpenFolderPanel("选择资源导出目录", buildData.exportResourceDirectory, "");
            buildData.exportResourceDirectory = selectPath;
            Repaint();
        }
        EditorGUILayout.Space();

        GUIContent copyContent = new GUIContent("3.是否将脚本拷贝至其他目录");
        bool copyCurrent = EditorGUILayout.ToggleLeft(copyContent, buildData.copy);
        buildData.copy = copyCurrent;

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

        GUIContent forceContent = new GUIContent("3.是否强制更新");
        bool forceCurrent = EditorGUILayout.ToggleLeft(forceContent, buildData.force);
        buildData.force = forceCurrent;

        EditorGUILayout.Space();
        EditorGUILayout.Space();

        if (GUILayout.Button("开始更新数据表"))
        {
            if (string.IsNullOrEmpty(buildData.dataSheetDirectory))
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
                        UpdateDataSheetToAsset();
                        break;
                    case DataFormatEnum.Json:
                        UpdateDataSheetToJosn();
                        break;
                    default:
                        break;
                }
                Close();
            }
        }
    }

    private void OnEnable()
    {
        LoadBuildData();
    }

    private void OnDisable()
    {
        SaveBuildData();
    }

    #endregion

    [Serializable]
    public class DataSheetBuildData
    {
        public string dataSheetDirectory;
        public string exportScriptDirectory;
        public string exportResourceDirectory;
        public bool copy;
        public string destScriptDirectory;
        public bool force;
        public DataFormatEnum format;
        public bool updating;
    }
}
