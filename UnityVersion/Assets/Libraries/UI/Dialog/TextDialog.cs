using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Events;
using System.Collections;

public class TextDialog : MonoBehaviour
{
    private static TextDialog instance;
    
    private GameObject dialogObject;
    private Canvas canvas;
    private Text titleText;
    private Text contentText;
    private Button confirmButton;
    private Button cancelButton;
    
    private void Awake()
    {
        // 单例模式
        if (instance != null && instance != this)
        {
            Destroy(gameObject);
            return;
        }
        instance = this;
        DontDestroyOnLoad(gameObject);
        
        // 创建UI元素
        CreateCanvas();
        CreateDialog();
        
        // 初始隐藏
        Hide();
    }
    
    private void CreateCanvas()
    {
        GameObject canvasObj = new GameObject("DialogCanvas");
        canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvasObj.AddComponent<CanvasScaler>();
        canvasObj.AddComponent<GraphicRaycaster>();
        DontDestroyOnLoad(canvasObj);
    }
    
    private void CreateDialog()
    {
        // 创建对话框背景
        dialogObject = new GameObject("Dialog");
        dialogObject.transform.SetParent(canvas.transform);
        
        // 添加背景图像
        Image bg = dialogObject.AddComponent<Image>();
        bg.color = new Color(0.2f, 0.2f, 0.2f, 0.9f);
        bg.rectTransform.sizeDelta = new Vector2(500, 300);
        bg.rectTransform.anchoredPosition = Vector2.zero;
        
        // 创建标题
        GameObject titleObj = new GameObject("Title");
        titleObj.transform.SetParent(dialogObject.transform);
        titleText = titleObj.AddComponent<Text>();
        titleText.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        titleText.color = Color.white;
        titleText.fontSize = 28;
        titleText.alignment = TextAnchor.UpperCenter;
        
        RectTransform titleRect = titleObj.GetComponent<RectTransform>();
        titleRect.anchorMin = new Vector2(0.1f, 0.7f);
        titleRect.anchorMax = new Vector2(0.9f, 0.9f);
        titleRect.offsetMin = Vector2.zero;
        titleRect.offsetMax = Vector2.zero;
        
        // 创建内容文本
        GameObject contentObj = new GameObject("Content");
        contentObj.transform.SetParent(dialogObject.transform);
        contentText = contentObj.AddComponent<Text>();
        contentText.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        contentText.color = Color.white;
        contentText.fontSize = 22;
        contentText.alignment = TextAnchor.MiddleCenter;
        
        RectTransform contentRect = contentObj.GetComponent<RectTransform>();
        contentRect.anchorMin = new Vector2(0.1f, 0.3f);
        contentRect.anchorMax = new Vector2(0.9f, 0.7f);
        contentRect.offsetMin = Vector2.zero;
        contentRect.offsetMax = Vector2.zero;
        
        // 创建确定按钮
        GameObject confirmObj = new GameObject("ConfirmButton");
        confirmObj.transform.SetParent(dialogObject.transform);
        confirmButton = confirmObj.AddComponent<Button>();
        
        Image confirmImage = confirmObj.AddComponent<Image>();
        confirmImage.color = new Color(0.1f, 0.5f, 0.1f, 1f);
        
        GameObject confirmTextObj = new GameObject("Text");
        confirmTextObj.transform.SetParent(confirmObj.transform);
        Text confirmText = confirmTextObj.AddComponent<Text>();
        confirmText.text = "确定";
        confirmText.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        confirmText.color = Color.white;
        confirmText.alignment = TextAnchor.MiddleCenter;
        
        RectTransform confirmTextRect = confirmTextObj.GetComponent<RectTransform>();
        confirmTextRect.anchorMin = Vector2.zero;
        confirmTextRect.anchorMax = Vector2.one;
        confirmTextRect.offsetMin = Vector2.zero;
        confirmTextRect.offsetMax = Vector2.zero;
        
        RectTransform confirmRect = confirmObj.GetComponent<RectTransform>();
        confirmRect.anchorMin = new Vector2(0.1f, 0.05f);
        confirmRect.anchorMax = new Vector2(0.45f, 0.2f);
        confirmRect.offsetMin = Vector2.zero;
        confirmRect.offsetMax = Vector2.zero;
        
        // 创建取消按钮
        GameObject cancelObj = new GameObject("CancelButton");
        cancelObj.transform.SetParent(dialogObject.transform);
        cancelButton = cancelObj.AddComponent<Button>();
        
        Image cancelImage = cancelObj.AddComponent<Image>();
        cancelImage.color = new Color(0.5f, 0.1f, 0.1f, 1f);
        
        GameObject cancelTextObj = new GameObject("Text");
        cancelTextObj.transform.SetParent(cancelObj.transform);
        Text cancelText = cancelTextObj.AddComponent<Text>();
        cancelText.text = "取消";
        cancelText.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        cancelText.color = Color.white;
        cancelText.alignment = TextAnchor.MiddleCenter;
        
        RectTransform cancelTextRect = cancelTextObj.GetComponent<RectTransform>();
        cancelTextRect.anchorMin = Vector2.zero;
        cancelTextRect.anchorMax = Vector2.one;
        cancelTextRect.offsetMin = Vector2.zero;
        cancelTextRect.offsetMax = Vector2.zero;
        
        RectTransform cancelRect = cancelObj.GetComponent<RectTransform>();
        cancelRect.anchorMin = new Vector2(0.55f, 0.05f);
        cancelRect.anchorMax = new Vector2(0.9f, 0.2f);
        cancelRect.offsetMin = Vector2.zero;
        cancelRect.offsetMax = Vector2.zero;
    }
    
    public static void ShowConfirm(string title, string content, UnityAction onConfirm, UnityAction onCancel = null)
    {
        if (instance == null)
        {
            Debug.LogError("DialogManager instance not found!");
            return;
        }
        
        instance.titleText.text = title;
        instance.contentText.text = content;
        
        // 清除旧的监听器
        instance.confirmButton.onClick.RemoveAllListeners();
        instance.cancelButton.onClick.RemoveAllListeners();
        
        // 添加新的监听器
        instance.confirmButton.onClick.AddListener(() => {
            instance.Hide();
            onConfirm?.Invoke();
        });
        
        instance.cancelButton.onClick.AddListener(() => {
            instance.Hide();
            onCancel?.Invoke();
        });
        
        instance.dialogObject.SetActive(true);
    }
    
    private void Hide()
    {
        dialogObject.SetActive(false);
    }
}