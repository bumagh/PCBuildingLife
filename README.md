# 装机人生 | PC Building Life

《装机人生》是一个以 Godot 开发的电脑装机模拟经营游戏。当前公开仓库提供 GodotVersion 主工程、游戏源码、自有运行时素材、策划文档和自动化验证脚本。

当前首发方式是 GitHub 源码仓库，不使用 itch.io，也不把本地构建产物或竞品参考图片提交到仓库。

## 快速开始

### 环境要求

- Windows 10/11 x86_64
- Godot 4.7 RC3，推荐使用项目约定的 `Godot_v4.7-rc3_win64_console.exe`
- Node.js 18 或更高版本，用于 MCP UI smoke
- PowerShell 5.1 或更高版本

### 打开并运行

1. 克隆仓库：

   ```powershell
   git clone https://github.com/bumagh/PCBuildingLife.git
   cd PCBuildingLife
   ```

2. 用 Godot 导入并打开 `GodotVersion/project.godot`。
3. 点击 Godot 编辑器的运行按钮，或使用命令行：

   ```powershell
   & 'D:\1exe\3Dev\1GameEngine\Godot_v4.7-rc3_win64\Godot_v4.7-rc3_win64.exe' --editor --path GodotVersion
   ```

4. 新建游戏后，按以下顺序体验首轮流程：查看订单、采购配件、进入仓库、拖动或点击安装、完成检测、按下电源按钮、进入模拟 OS、完成驱动/跑分/稳定性任务并交付订单。

## 构建 Windows 版本

使用项目发布入口生成本地 Windows x86_64 包：

```powershell
& .\GodotVersion\scripts\build_release.ps1
```

输出位于 `GodotVersion/build/windows/`。该目录被 Git 忽略，避免把临时导出、存档、截图和构建副本提交到仓库。构建脚本会执行核心 headless 回归、12 单玩家流程、首单保存/读取、公开包 guard、EXE 启动和 ZIP 解压启动检查。

## 自动化验证

完整本地发布回归：

```powershell
& .\GodotVersion\scripts\build_release.ps1
& .\GodotVersion\scripts\verify_reference_asset_boundary.ps1
& .\GodotVersion\scripts\verify_ui_visual_screenshots.ps1
node .\GodotVersion\scripts\mcp_ui_smoke.mjs
```

UI 截图验证覆盖 1280x720、1366x768 和 1920x1080。截图会检查首页底部 Dock、工作台、订单大厅、配件市场、仓库、任务中心、系统中心和 Max Monitor 的实际窗口布局。

## 项目结构

- `GodotVersion/`：当前 Godot 主工程。
- `UnityVersion/`：历史 Unity 原型，仅作迁移和玩法参考。
- `doc/`：策划案、开发排期、竞品行为记录、素材边界和上线验收资料。
- `GodotVersion/assets/original/`：公开运行时使用的自有程序化素材。
- `ReferenceAssets/PC_Creator2/README.md`：竞品参考归档说明。竞品图片和历史导入副本只保留在本机，不进入 GitHub。

## 当前版本内容

- 订单、商店、仓库、购买并安装和拖动安装。
- CPU、散热器、主板、内存、显卡、硬盘、电源和机箱的装机槽位与兼容性检查。
- 电源开机、可最大化的模拟显示器和模拟 OS。
- Driver Tool、系统信息、Benchmark、Stability Test、Files 和交付前检查。
- 软件配置完成度会影响交付评分和订单结果。
- 12 单首发订单、保存读取、新手引导、金手指开发测试入口和自动化玩家流程。

## 当前候选包证据

- 版本：`0.1.0-dev`
- Windows ZIP SHA-256：`dc5a2cec06e35799c8535886f0dd76897f36645e866467defcc2f0e28dd9b73d`
- Windows EXE SHA-256：`d72e724a2c635c17ffeb74cd578a21e7b45812565d5b8da487c6ee8a4ec8b0ef`
- 本机视觉套件：`warnings=0`
- MCP UI smoke：到达“交付订单”

哈希绑定的完整报告保留在本机 `GodotVersion/build/`，不会进入 GitHub 源码提交。

## 反馈与许可边界

问题反馈：<https://github.com/bumagh/PCBuildingLife/issues>

当前仓库没有授予第三方商业再发行许可。公开运行时使用项目自有程序化素材；竞品资料只用于本地玩法和界面研究，不复制竞品代码、品牌、Logo、商标、完整文案或未授权素材。正式商业发行前需要单独补充许可证和第三方依赖声明。

## 当前限制

当前版本以核心装机经营闭环和模拟 OS 任务为主，长期职业路线、随机事件、比赛、Steam SDK、云存档、多人和复杂内购仍未纳入首发范围。GitHub 仓库是源码分发入口，玩家可以按上面的构建步骤生成 Windows 包。
