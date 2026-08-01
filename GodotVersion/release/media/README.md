# 发布截图素材

本目录保存 `0.1.0-dev` 发布页候选截图。所有截图来自 Godot 图形验证脚本生成的真实游戏画面。

## 文件

| 文件 | 内容 | 尺寸 |
| --- | --- | --- |
| `01-main-menu.png` | 主菜单 | 1280x720 |
| `02-workbench.png` | 工作台与底部流程 | 1920x1080 |
| `03-order-desk.png` | 订单大厅 | 1920x1080 |
| `04-catalog-shop.png` | 配件市场 | 1920x1080 |
| `05-catalog-inventory.png` | 仓库 | 1920x1080 |
| `06-task-center.png` | 任务中心 | 1920x1080 |
| `07-system-center.png` | 系统中心 | 1920x1080 |
| `08-max-monitor.png` | Max Monitor 模拟系统 | 1920x1080 |
| `09-delivery-feedback.png` | 交付评分回执 | 1280x720 |
| `cover-1920x1080.png` | 16:9 发布封面 | 1920x1080 |
| `channel-header-1920x620.png` | 渠道横幅头图 | 1920x620 |
| `small-cover-630x500.png` | 小封面/卡片封面 | 630x500 |
| `contact-sheet.png` | 九宫格快速检查图 | 1920x1182 |
| `branding-sheet.png` | 封面素材快速检查图 | 1920x360 |

## 验证记录

- `verify_main_menu_screenshot.gd` 通过，并生成 1280x720、1366x768、1920x1080 三档新游戏/继续游戏截图。
- `verify_ui_screenshot.gd` 通过，并在高 DPI 下保存为 1280x720。
- `verify_home_bottom_dock_screenshot.gd` 通过，并生成 1280x720、1366x768、1920x1080 三档首页底部 Dock 截图；`02-workbench.png` 已使用 1920x1080 最新截图。
- `verify_r3_screenshot.gd` 通过，并生成 1280x720、1366x768、1920x1080 三档回执截图。
- 工作台、订单大厅、全屏目录、任务中心、系统中心和 Max Monitor 截图均可被 Windows 图片库读取。
- `generate_release_contact_sheet.ps1` 会从 9 张当前发布截图重新生成 `contact-sheet.png`，避免快速检查图继续引用旧画面。

## 注意

当前候选截图、封面和渠道头图已经使用 `GodotVersion/assets/original` 下的自有程序化运行时素材或项目程序化发布图。统一反馈入口为 `https://github.com/bumagh/PCBuildingLife/issues`。
