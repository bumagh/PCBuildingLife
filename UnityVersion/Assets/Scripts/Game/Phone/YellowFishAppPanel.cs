
using UnityEngine;
using UnityEngine.UI;

public class YellowFishAppPanel : MonoBehaviour
{
    private GameObject panel;
    private Transform content;
    private Transform empty;
    private Button yellowFishBtn;
    private Button backBtn;
    private Text titleText;
    void Awake()
    {
        panel = transform.Find("Panel").gameObject;
        // yellowFishBtn = transform.Find("Panel/CenterScrollList/Viewport/Content/YellowFishApp").GetComponent<Button>();
        // titleText = transform.Find("Panel/TopTitle/Text").GetComponent<Text>();
        content = transform.Find("Panel/CenterScrollList/Viewport/Content");
        // empty = transform.Find("Panel/Empty");
        EventManager.AddEvent<bool>(EventName.ShowYellowFishAppPanel, this.ShowYellowFishAppPanel);
        backBtn = transform.Find("Panel/BackBtn").GetComponent<Button>();
        backBtn.onClick.AddListener(() =>
        {
            ShowYellowFishAppPanel(false);
        });
        // yellowFishBtn.onClick.AddListener(() =>
        // {
        //     ShowPhonePanel(false);
        // });
    }

    private void ClearUI()
    {
        for (int i = 0; i < content.childCount; i++)
        {
            var item = content.GetChild(i);
            Destroy(item.gameObject);
        }
    }
    private void ShowYellowFishAppPanel(bool show)
    {
        panel.SetActive(show);
      
        if (show)
        {
            ClearUI();
            // var prefab = Resources.Load<GameObject>("Prefabs/FishGoodsGrid");
            // var go = GameObject.Instantiate(prefab, content);
            var data = TableDataMgr.GetSingleCoreCompTableData(10001);
            Debug.Log(data.id);
            // foreach (var item in GameData.Instance.items)
            // {
            //     var goodsItem = ConfigData.goods.Find(ele => ele.GoodsID == item.Key);
            //     if (goodsItem == null) return;
            //     if (item.Value <= 0) return;
            //     if (goodsItem.GoodsTypeId != 1)
            //     {
            //         var go = GameObject.Instantiate(prefab, content);
            //         var goodsNameText = go.transform.Find("Name").GetComponent<Text>();
            //         var goodsDescText = go.transform.Find("Description").GetComponent<Text>();
            //         var goodsCountText = go.transform.Find("Count").GetComponent<Text>();
            //         var goodsButton = go.transform.Find("Button").GetComponent<Button>();
            //         goodsNameText.text = goodsItem.GoodsName;
            //         goodsDescText.text = goodsItem.GoodsDescribed;
            //         goodsCountText.text = item.Value.ToString() + "个";
            //         goodsButton.onClick.AddListener(() =>
            //         {
            //             UseGoods(goodsItem);
            //             ShowBagPanel(true);
            //         });
            //     }
            // }
        }
        else
        {
            
        }
    }

    void OnDestroy()
    {
        EventManager.RemoveEvent<bool>(EventName.ShowYellowFishAppPanel, this.ShowYellowFishAppPanel);

    }
}