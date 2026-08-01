# PC Building Life 0.1.0-dev 发布说明

## 版本定位

`0.1.0-dev` 是 Windows 公开试玩候选包，用于验证《装机人生》的核心可玩闭环：接单、采购、装机、开机、模拟 OS 软件配置、跑分、交付评分、收益和存档。

## 主要内容

- 12 个首发订单，包含不同客户类型、难度、奖励和软件任务。
- 配件市场、仓库、购买并安装、拖拽安装、出售和筛选。
- 工作台可视化插槽、装机检查、兼容性检查和电源按钮。
- 模拟 OS：系统信息、Driver Tool、GPU 驱动、Benchmark、稳定性测试、文件页和关机。
- 任务中心、订单大厅、系统中心、目录覆盖层和交付回执。
- 保存/读取、坏档恢复、设置菜单、主菜单和新手引导。
- 配件图标、配件详情预览、PC 预览和应用图标已切换为本项目自有程序化素材。
- 公开 release 包隐藏金手指、MCP、自动化玩家流、首单审计入口和测试脚本。

## 验证状态

本版本的发布脚本会执行以下关键验证：

- 内部验证包完成 12 个首发订单的玩家流。
- 每单后保存并读取，确认进度不丢失。
- 内部首单审计包在干净临时目录完成第一单、保存并读取，确认导出后的 Windows 运行时可完成首单闭环。
- 公开包执行双 guard，确认 `--pcbl-release-flow` 和 `--pcbl-first-order-audit` 不会暴露自动化入口。
- 公开 EXE 可启动并停留运行；公开 ZIP 解压后也会执行启动冒烟。
- `release-manifest.json` 记录 EXE SHA-256、玩家流订单数、保存/读取次数、首单审计结果和公开包守卫状态。

## 已知限制

- 当前内容以首发订单池为主，长期经营、职业差异、事件系统和竞赛玩法仍在扩展中。
- 模拟 OS 目前是轻量玩法层，后续会作为 DLC/扩展方向继续深化。
- 正式商店封面、渠道头图、版权声明和基础反馈说明已准备；统一反馈入口为 GitHub Issues。
- 暂未接入 Steam/itch 平台 SDK。
- 当前仅提供 Windows Desktop 包。

## 发布文件

- `PCBuildingLife.exe`：游戏本体。
- `release-manifest.json`：构建、校验和自动化验证摘要。
- `README.txt`：玩家启动说明。
- `RELEASE_NOTES.md`：本文件。
- `COLLECT_SUPPORT_BUNDLE.cmd` / `COLLECT_SUPPORT_BUNDLE.ps1`：问题反馈支持信息收集器，会生成系统摘要、存档摘要和最近日志，不直接打包原始存档。
- `PCBuildingLife-Windows-x64-0.1.0-dev.zip.sha256`：ZIP 文件 SHA-256，位于 ZIP 外。

## 版权

PC Building Life / 装机人生

Copyright (c) 2026 AKG Studio. All rights reserved.

Built with Godot Engine. Godot Engine is available under the MIT License.

## 反馈入口

- GitHub Issues：https://github.com/bumagh/PCBuildingLife/issues
- 反馈时建议包含游戏版本、Windows 版本、分辨率/全屏状态、复现步骤、预期结果、实际结果，以及截图或录屏。
- 如果遇到崩溃、黑屏或无法继续，可以运行随包的 `COLLECT_SUPPORT_BUNDLE.cmd`，把生成的支持 ZIP 一起提交。
