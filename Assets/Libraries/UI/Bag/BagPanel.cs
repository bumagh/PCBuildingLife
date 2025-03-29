
using UnityEngine;
using UnityEngine.UI;

public class BagPanel : MonoBehaviour
{
    private GameObject panel;
    private Transform content;
    private Button backBtn;
    void Awake()
    {
        panel = transform.Find("Panel").gameObject;
        content = transform.Find("Panel/CenterScrollList/Viewport/Content");
        EventManager.AddEvent<bool>(EventName.ShowBagPanel, this.ShowBagPanel);
        backBtn = transform.Find("Panel/BackBtn").GetComponent<Button>();
        backBtn.onClick.AddListener(() =>
        {
            ShowBagPanel(false);
        });
    }

    private void ClearUI()
    {
        for (int i = 0; i < content.childCount; i++)
        {
            var item = content.GetChild(i);
            Destroy(item.gameObject);
        }
    }
    private void ShowBagPanel(bool show)
    {
        panel.SetActive(show);
        if (show)
        {
            ClearUI();
            // var prefab = Resources.Load<GameObject>("Prefabs/Arcade/GoodsItem");
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
    }
   
    void OnDestroy()
    {
        EventManager.RemoveEvent<bool>(EventName.ShowBagPanel, this.ShowBagPanel);

    }
}