/**
* UnityVersion: 2019.3.15f1
* FileName:     Utf8jsonHelper.cs
* Author:       TANYUQING
* CreateTime:   2020/09/07 15:43:23
* Description:  
*/
using Utf8Json.Resolvers;
using Utf8Json.Formatters;

public static class Utf8jsonHelper
{
    public static void RuntimeInitialize()
    {
        CompositeResolver.RegisterAndSetAsDefault(
            new[] { GeneratedResolver.Instance,
                    BuiltinResolver.Instance,
                    EnumResolver.Default,
                    DynamicGenericResolver.Instance });
        new DictionaryFormatter<int, int>();
        new DictionaryFormatter<int, string>();
        new DictionaryFormatter<string, int>();
        //new DictionaryFormatter<int, ShopUIResourceBuyMsg>();
        //new DictionaryFormatter<int, NauticalAdventureLevelData>();
    }

    public static void EditorInitialize()
    {
        CompositeResolver.isFreezed = false;
        CompositeResolver.RegisterAndSetAsDefault(StandardResolver.Default);
    }
}
