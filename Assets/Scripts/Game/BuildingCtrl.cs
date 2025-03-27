using UnityEngine;
using UnityEngine.UI;

public class BuildingCtrl : MonoBehaviour
{
    // Start is called before the first frame update
    private Button exitBtn;
    private Button flagBtn;

    private Image monitorScreenImg;
    private bool pcWork = false;
    void Start()
    {
        exitBtn = transform.Find("Exit").GetComponent<Button>();
        flagBtn = transform.Find("FlagFinish").GetComponent<Button>();
        monitorScreenImg = transform.Find("Monitor/Screen").GetComponent<Image>();
        exitBtn.onClick.AddListener(()=>{
            gameObject.SetActive(false);
            //TODO:需要确定是否保存
        });
        flagBtn.onClick.AddListener(()=>{
            //TODO:需要检测是否缺少材料
            //缺少屏幕显示红色
            if(pcWork){
                monitorScreenImg.color = Color.blue;
            }else{
                monitorScreenImg.color = Color.red;
                TextTip.Show("缺少零件，电脑无法正常工作");
            }
        });
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
