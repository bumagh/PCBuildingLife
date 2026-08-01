using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Events;
using System;

public class VersionUpdateDialog : MonoBehaviour
{
    private static VersionUpdateDialog instance;
    
    private GameObject dialogObject;
    private Canvas canvas;
    private Text contentText;
    private Text progressText;
    private Slider progressSlider;
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
        GameObject canvasObj = new GameObject("VersionUpdateCanvas");
        canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvasObj.AddComponent<CanvasScaler>();
        canvasObj.AddComponent<GraphicRaycaster>();
        DontDestroyOnLoad(canvasObj);
    }
    
    private void CreateDialog()
    {
        // 创建对话框背景
        dialogObject = new GameObject("VersionUpdateDialog");
        dialogObject.transform.SetParent(canvas.transform);
        
        // 添加背景图像
        Image bg = dialogObject.AddComponent<Image>();
        bg.color = new Color(0.2f, 0.2f, 0.2f, 0.9f);
        bg.rectTransform.sizeDelta = new Vector2(500, 300);
        bg.rectTransform.anchoredPosition = Vector2.zero;
        
        // 创建内容文本
        GameObject contentObj = new GameObject("ContentText");
        contentObj.transform.SetParent(dialogObject.transform);
        contentText = contentObj.AddComponent<Text>();
        contentText.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        contentText.color = Color.white;
        contentText.fontSize = 22;
        contentText.alignment = TextAnchor.MiddleCenter;
        
        RectTransform contentRect = contentObj.GetComponent<RectTransform>();
        contentRect.anchorMin = new Vector2(0.1f, 0.6f);
        contentRect.anchorMax = new Vector2(0.9f, 0.9f);
        contentRect.offsetMin = Vector2.zero;
        contentRect.offsetMax = Vector2.zero;
        
        // 创建进度条
        GameObject sliderObj = new GameObject("ProgressSlider");
        sliderObj.transform.SetParent(dialogObject.transform);
        progressSlider = sliderObj.AddComponent<Slider>();
        
        // 进度条背景
        GameObject bgObj = new GameObject("Background");
        bgObj.transform.SetParent(sliderObj.transform);
        Image bgImage = bgObj.AddComponent<Image>();
        bgImage.color = new Color(0.3f, 0.3f, 0.3f, 1f);
        
        // 进度条填充
        GameObject fillObj = new GameObject("Fill");
        fillObj.transform.SetParent(sliderObj.transform);
        Image fillImage = fillObj.AddComponent<Image>();
        fillImage.color = new Color(0.1f, 0.5f, 0.1f, 1f);
        
        // 进度条手柄（不需要，可以禁用）
        progressSlider.handleRect = null;
        
        // 设置进度条样式
        progressSlider.targetGraphic = fillImage;
        progressSlider.fillRect = fillImage.rectTransform;
        
        RectTransform sliderRect = sliderObj.GetComponent<RectTransform>();
        sliderRect.anchorMin = new Vector2(0.1f, 0.4f);
        sliderRect.anchorMax = new Vector2(0.9f, 0.5f);
        sliderRect.offsetMin = Vector2.zero;
        sliderRect.offsetMax = Vector2.zero;
        
        // 进度文本
        GameObject progressObj = new GameObject("ProgressText");
        progressObj.transform.SetParent(dialogObject.transform);
        progressText = progressObj.AddComponent<Text>();
        progressText.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        progressText.color = Color.white;
        progressText.fontSize = 18;
        progressText.alignment = TextAnchor.MiddleCenter;
        
        RectTransform progressRect = progressObj.GetComponent<RectTransform>();
        progressRect.anchorMin = new Vector2(0.1f, 0.3f);
        progressRect.anchorMax = new Vector2(0.9f, 0.4f);
        progressRect.offsetMin = Vector2.zero;
        progressRect.offsetMax = Vector2.zero;
        
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
        cancelRect.anchorMin = new Vector2(0.3f, 0.1f);
        cancelRect.anchorMax = new Vector2(0.7f, 0.2f);
        cancelRect.offsetMin = Vector2.zero;
        cancelRect.offsetMax = Vector2.zero;
    }
    
    public static void Show(string content, UnityAction onCancel = null)
    {
        if (instance == null)
        {
            Debug.LogError("VersionUpdateDialog instance not found!");
            return;
        }
        
        instance.contentText.text = content;
        instance.progressText.text = "0%";
        instance.progressSlider.value = 0;
        
        // 清除旧的监听器
        instance.cancelButton.onClick.RemoveAllListeners();
        
        // 添加新的监听器
        instance.cancelButton.onClick.AddListener(() => {
            instance.Hide();
            onCancel?.Invoke();
        });
        
        instance.dialogObject.SetActive(true);
    }
    
    public static void UpdateProgress(float progress)
    {
        if (instance == null || !instance.dialogObject.activeSelf) return;
        
        float clampedProgress = Mathf.Clamp01(progress / 100f);
        instance.progressSlider.value = clampedProgress;
        instance.progressText.text = $"{Math.Round(progress)}%";
    }
    
    private void Hide()
    {
        dialogObject.SetActive(false);
    }
    
    public static void Close()
    {
        if (instance != null)
        {
            instance.Hide();
        }
    }
}