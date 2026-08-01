using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using System.Collections;

public class ShapeButton : MonoBehaviour, IPointerClickHandler
{
    private Coroutine scaleCoroutine;
    private Vector3 originalScale;
 private PolygonCollider2D _collider;
    private void Awake()
    {
         _collider = GetComponent<PolygonCollider2D>();
        _collider.isTrigger = true;
        originalScale = transform.localScale;
    }

    public void OnPointerClick(PointerEventData eventData)
    {
        Debug.Log("Diamond button clicked!");
        Vector2 localPoint;
        RectTransformUtility.ScreenPointToLocalPointInRectangle(
            transform as RectTransform, 
            eventData.position, 
            eventData.pressEventCamera, 
            out localPoint);

        if (_collider.OverlapPoint(localPoint))
        {
            Debug.Log("精确点击在碰撞器范围内");
            // 执行点击逻辑
        }
        // 如果已经有特效在运行，先停止它
       
    }
    
    IEnumerator ScaleEffect()
    {
        float duration = 0.2f;
        float elapsed = 0f;
        Vector3 targetScale = originalScale * 1.2f;
        
        // 放大阶段
        while (elapsed < duration)
        {
            transform.localScale = Vector3.Lerp(originalScale, targetScale, elapsed/duration);
            elapsed += Time.deltaTime;
            yield return null;
        }
        
        elapsed = 0f;
        // 缩小阶段
        while (elapsed < duration)
        {
            transform.localScale = Vector3.Lerp(targetScale, originalScale, elapsed/duration);
            elapsed += Time.deltaTime;
            yield return null;
        }
        
        transform.localScale = originalScale;
        scaleCoroutine = null; // 重置协程引用
    }
}