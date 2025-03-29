using System.Collections;
using UnityEngine;
using UnityEngine.UI;

public class AlphaHitButton : MonoBehaviour
{
    [Range(0, 1)]
    public float alphaThreshold = 0.1f;
    private Coroutine scaleCoroutine;
    private Vector3 originalScale;

    void Awake()
    {
        originalScale = transform.localScale;

    }
    private void Start()
    {
        GetComponent<Image>().alphaHitTestMinimumThreshold = alphaThreshold;
        GetComponent<Button>().onClick.AddListener(() =>
        {
            if (scaleCoroutine != null)
            {
                StopCoroutine(scaleCoroutine);
                transform.localScale = originalScale; // 立即恢复到原始大小
            }

            // 启动新的特效
            scaleCoroutine = StartCoroutine(ScaleEffect());
        });
    }
    IEnumerator ScaleEffect()
    {
        float duration = 0.2f;
        float elapsed = 0f;
        Vector3 targetScale = originalScale * 1.2f;

        // 放大阶段
        while (elapsed < duration)
        {
            transform.localScale = Vector3.Lerp(originalScale, targetScale, elapsed / duration);
            elapsed += Time.deltaTime;
            yield return null;
        }

        elapsed = 0f;
        // 缩小阶段
        while (elapsed < duration)
        {
            transform.localScale = Vector3.Lerp(targetScale, originalScale, elapsed / duration);
            elapsed += Time.deltaTime;
            yield return null;
        }

        transform.localScale = originalScale;
        scaleCoroutine = null; // 重置协程引用
    }
}