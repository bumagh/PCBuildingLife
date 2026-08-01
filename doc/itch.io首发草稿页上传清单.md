# 《装机人生》itch.io 首发草稿页上传清单

> 已弃用（2026-08-01）：当前首发渠道改为 GitHub 源码仓库。本文仅保留历史 itch.io 流程，不作为当前上线步骤；请使用 `doc/GitHub仓库上线清单.md` 和根目录 `README.md`。

## 当前策略

首发建议使用 itch.io 草稿页或限量可见页面，暂不直接做正式商业上架。当前 0.1.0-dev 已具备核心装机闭环、模拟 OS、12 单玩家流、首单审计、发布包审计和本地下载页验收；itch.io 适合作为第一批外部玩家测试入口。

官方参考：

- butler pushing builds：<https://itch.io/docs/butler/pushing.html>
- butler installing：<https://itch.io/docs/butler/installing.html>
- itch app 上传功能说明：<https://itch.io/updates/pushing-builds-with-butler-is-now-in-the-itch-app>

## 上传前本地准备

先运行：

```powershell
& .\GodotVersion\scripts\prepare_release_upload_bundle.ps1
& .\GodotVersion\scripts\verify_itch_upload_config.ps1
& .\GodotVersion\scripts\prepare_itch_upload.ps1 -Hidden
& .\GodotVersion\scripts\verify_itch_staging.ps1
```

生成目录：

```text
GodotVersion/build/itch/PCBuildingLife-0.1.0-dev/
```

目录内容：

- `package/PCBuildingLife-Windows-x64-0.1.0-dev.zip`
- `package/PCBuildingLife-Windows-x64-0.1.0-dev.zip.sha256`
- `package/release-package-audit-report.json`
- `media/cover-1920x1080.png`
- `media/channel-header-1920x620.png`
- `media/small-cover-630x500.png`
- `media/contact-sheet.png`
- `media/branding-sheet.png`
- `docs/*.md`
- `itch-upload-manifest.json`
- `butler-command.txt`

## itch.io 页面字段

- Project title：`装机人生 / PC Building Life`
- Short description：`电脑装机模拟经营试玩候选版`
- Classification：`Game`
- Kind of project：`Downloadable`
- Pricing：`No payments / Free`，首轮建议免费试玩。
- Visibility：建议先用 `Draft` 或受限分享；确认外部验收后再公开。
- Platform：`Windows`
- Language：`Simplified Chinese`
- Genre / Tags：`Simulation`、`Management`、`PC Building`、`Hardware`、`Singleplayer`

简介、长简介、系统要求、已知限制和隐私反馈文案直接使用：

```text
GodotVersion/build/itch/PCBuildingLife-0.1.0-dev/docs/首发渠道页面草稿.md
```

## 推荐图片

页面封面：

```text
GodotVersion/build/itch/PCBuildingLife-0.1.0-dev/media/cover-1920x1080.png
```

频道头图：

```text
GodotVersion/build/itch/PCBuildingLife-0.1.0-dev/media/channel-header-1920x620.png
```

小封面：

```text
GodotVersion/build/itch/PCBuildingLife-0.1.0-dev/media/small-cover-630x500.png
```

截图顺序继续使用 `GodotVersion/release/media/` 中的：

1. `01-main-menu.png`
2. `02-workbench.png`
3. `03-order-desk.png`
4. `04-catalog-shop.png`
5. `05-catalog-inventory.png`
6. `06-task-center.png`
7. `07-system-center.png`
8. `08-max-monitor.png`
9. `09-delivery-feedback.png`

## butler 上传

如果安装了 itch app 26.12.0 或之后版本，可以直接在 app 的 Upload 界面推送构建；如果使用命令行，先登录：

```powershell
butler login
```

首次上传前，把公开模板复制为本地配置，并填入真实 itch 项目：

```powershell
Copy-Item .\GodotVersion\release\itch-upload-config.example.json .\GodotVersion\release\itch-upload-config.local.json
notepad .\GodotVersion\release\itch-upload-config.local.json
& .\GodotVersion\scripts\verify_itch_upload_config.ps1 -RequireTarget
```

`itch-upload-config.local.json` 已加入 `.gitignore`，只用于本机上传，不应提交。配置字段：

- `itch_target`：形如 `itch-user/itch-game`。
- `channel`：默认 `windows-demo`。
- `hidden`：首轮建议 `true`，上传后先检查再公开。
- `if_changed`：建议 `true`，重复执行时只在内容变化时上传。
- `public_package_url` / `public_sha256_url`：真实公开下载地址产生后可填入，后续生成的命令会自动带入下载验收。

生成上传命令：

```powershell
& .\GodotVersion\scripts\prepare_itch_upload.ps1
```

真正推送：

```powershell
& .\GodotVersion\scripts\advance_external_release.ps1 -Push
```

推荐使用 `advance_external_release.ps1` 作为外部发布轮次入口。它会先确认当前玩家 ZIP 哈希、真实 itch 目标、隐藏 channel 和 butler 环境，成功上传后自动处理回件目录并刷新 readiness 与最终 go/no-go。没有 `-Push` 时只做预检、报告回收和门禁刷新，不会访问外部渠道。

底层排障时仍可单独运行 `prepare_itch_upload.ps1 -Push`。该脚本会先写入 `push_requested=true, pushed=false`；只有 butler 返回退出码 0 才会把 manifest 改为 `pushed=true`，网络、登录或目标错误不会被误记为上传成功。

说明：

- `windows-demo` channel 名包含 `windows`，便于 itch 识别平台。
- `-Hidden` 会先把新 channel 设为隐藏，方便上传后检查再公开。
- `-Public` 可以覆盖配置中的 `hidden`，用于确认无误后推送公开 channel。
- 同一个 channel 后续重复推送会更新已有构建。
- 不要把 butler 登录 token、API key 或账号凭据写入仓库。

## 上传后验收

上传完成后，从 itch 页面复制真实 ZIP 下载地址和 `.sha256` 下载地址，运行：

```powershell
& .\GodotVersion\scripts\verify_public_download.ps1 -PackageUrl '<ZIP 下载地址>' -Sha256Url '<SHA-256 下载地址>' -ExpectedPackageSha256 '05c8a34a8072ef229c161802ecd82cb9a1bcf8d38e6ff561b3d7e1e1acc88c76'
```

也可以把两个 URL 写入 `itch-upload-config.local.json` 后执行：

```powershell
& .\GodotVersion\scripts\advance_external_release.ps1
& .\GodotVersion\scripts\advance_external_release.ps1 -RequireGo
```

第一条会自动下载验收并处理已回收报告；第二条只在最终门禁得到 `go_public_release` 时返回成功。

通过后将实际页面地址、下载地址、验收时间和验收结果写回：

```text
doc/上线交付清单.md
```

最终外部验收仍需要至少一次真实玩家路径：

1. 从 itch 页面下载 ZIP。
2. 解压到普通目录。
3. 启动 `PCBuildingLife.exe`。
4. 新游戏完成第一单 `社区办公机`。
5. 保存并重启确认可以继续游戏。
6. 提交一次测试反馈或确认 GitHub Issues 入口可访问。
