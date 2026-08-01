using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

public class TextTip : MonoBehaviour
{
    // 单例模式便于访问
    private static TextTip instance;
    
    private Text tooltipText;
    private GameObject tooltipObject;
    private Canvas canvas;
    private float hideTime;
    private bool isShowing;
    private UnityAction hideAction=null;
    private void Awake()
    {
        // 确保单例
        if (instance != null && instance != this)
        {
            Destroy(gameObject);
            return;
        }
        instance = this;
        
        // 创建Canvas
        CreateCanvas();
        
        // 创建提示对象
        CreateTooltipObject();
        
        // 初始隐藏
        Hide();
    }

    private void CreateCanvas()
    {
        // 创建Canvas对象
        GameObject canvasObj = new GameObject("TooltipCanvas");
        canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvasObj.AddComponent<CanvasScaler>();
        canvasObj.AddComponent<GraphicRaycaster>();
        
        // 设为常驻对象
        DontDestroyOnLoad(canvasObj);
    }

    private void CreateTooltipObject()
    {
        // 创建提示背景
        tooltipObject = new GameObject("Tooltip");
        tooltipObject.transform.SetParent(canvas.transform);
        
        // 添加背景图像
        Image bg = tooltipObject.AddComponent<Image>();
        bg.color = new Color(0.2f, 0.2f, 0.2f, 0.8f);
        
        // 添加文本组件
        GameObject textObj = new GameObject("TooltipText");
        textObj.transform.SetParent(tooltipObject.transform);
        tooltipText = textObj.AddComponent<Text>();
        
        // 设置文本样式
        tooltipText.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        tooltipText.color = Color.white;
        tooltipText.alignment = TextAnchor.MiddleCenter;
        tooltipText.fontSize = 24;
        
        // 设置RectTransform
        RectTransform textRect = textObj.GetComponent<RectTransform>();
        textRect.anchorMin = Vector2.zero;
        textRect.anchorMax = Vector2.one;
        textRect.offsetMin = Vector2.zero;
        textRect.offsetMax = Vector2.zero;
        
        // 设置提示框大小
        RectTransform bgRect = tooltipObject.GetComponent<RectTransform>();
        bgRect.sizeDelta = new Vector2(400, 100);
        bgRect.anchoredPosition = Vector2.zero;
    }

    private void Update()
    {
        if (isShowing && Time.time >= hideTime)
        {
            Hide();
        }
    }

    public static void Show(string message, float duration = 2f, UnityAction hideAction=null)
    {
        if (instance == null)
        {
            Debug.LogError("Tooltip instance not found!");
            return;
        }
        
        instance.tooltipText.text = message;
        instance.tooltipObject.SetActive(true);
        instance.hideTime = Time.time + duration;
        instance.isShowing = true;
        instance.hideAction = hideAction;
        
    }

    public static void Hide()
    {
        if (instance == null) return;
        
        instance.tooltipObject.SetActive(false);
        instance.isShowing = false;
        instance.hideAction?.Invoke();
    }
}