# 《装机人生》GitHub 仓库上线清单

## 当前渠道

首发渠道改为 GitHub 源码仓库：

<https://github.com/bumagh/PCBuildingLife>

不创建 itch.io 页面，不上传 GitHub Release asset。仓库根目录 `README.md` 是玩家和开发者的统一入口，说明 Godot 打开、运行、Windows 构建、自动化测试、反馈入口和素材边界。

## 推送内容

应提交：

- `GodotVersion/` 主工程、场景、脚本、数据和自有运行时素材。
- `UnityVersion/` 历史原型，用于迁移参考。
- `doc/` 策划案、排期、测试和版权边界资料。
- 根目录 `README.md`、`.gitignore` 和必要的 GitHub Issue 模板。
- `ReferenceAssets/PC_Creator2/README.md` 参考边界说明。

不得提交：

- `ReferenceAssets/PC_Creator2` 下的竞品 PNG、图片目录和 `legacy_godot_project_copy`。
- `GodotVersion/build/`、`GodotVersion/tmp/`、导出的 ZIP/EXE、临时截图和本地存档。
- `*local.json`、token、API key、butler 凭据或其他本机配置。

## 推送前检查

```powershell
git status --short
git check-ignore -v ReferenceAssets/PC_Creator2/Main.png
git check-ignore -v ReferenceAssets/PC_Creator2/legacy_godot_project_copy
git check-ignore -v GodotVersion/build/windows/PCBuildingLife-Windows-x64-0.1.0-dev.zip
& .\GodotVersion\scripts\verify_reference_asset_boundary.ps1
& .\GodotVersion\scripts\verify_ui_visual_screenshots.ps1
node .\GodotVersion\scripts\mcp_ui_smoke.mjs
```

检查待提交文件中不存在竞品图片、构建产物、存档、凭据和本地配置后，再提交到 `main`。

## 玩家使用方式

玩家打开 GitHub 页面后，按根目录 README：

1. 克隆仓库。
2. 用 Godot 4.7 RC3 打开 `GodotVersion/project.godot`。
3. 直接运行项目，或执行 `GodotVersion/scripts/build_release.ps1` 生成 Windows 包。
4. 通过 GitHub Issues 提交问题、截图和复现步骤。

## 当前交付结论

GitHub 仓库推送成功、远程 README 可见、公开仓库边界检查通过后，源码首发交付完成。Windows ZIP 的本地构建证据仍保留在开发机，不把本地构建哈希误称为 GitHub Release 下载证据。

## 旧 itch 流程

`doc/itch.io首发草稿页上传清单.md` 仅作为历史流程留档，不属于当前发布步骤。
