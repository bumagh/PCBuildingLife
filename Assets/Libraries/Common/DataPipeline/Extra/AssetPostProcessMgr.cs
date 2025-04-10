/**
* UnityVersion: 2019.3.15f1
* FileName:     AssetPostProcessMgr.cs
* Author:       TANYUQING
* CreateTime:   2020/09/07 15:43:23
* Description:  
*/
#if UNITY_EDITOR
using UnityEditor;

public class AssetPostProcessMgr : AssetPostprocessor
{
    public static bool enabled = true;

    private static void OnPostprocessAllAssets(string[] importedAssets, string[] deletedAssets, string[] movedAssets, string[] movedFromAssetPaths)
    {
        if (enabled == false)
        {
            return;
        }
    }
}
#endif
