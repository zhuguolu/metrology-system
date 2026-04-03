# iOS 安装包交付说明

本目录是基于当前安卓原生版接口协议整理的 iOS 工程骨架（SwiftUI）。

## 已包含模块

- 登录（`/api/auth/login`）
- 总览看板（`/api/devices/dashboard`）
- 设备台账（`/api/devices/paged`，支持搜索、分页、详情）
- 台账编辑（`/api/devices/{id}`，设备详情内可编辑并保存）
- 校准管理（`/api/devices/paged` + `todoOnly=false`，支持快速“校准完成”）
- 我的待办（`/api/devices/paged` + `todoOnly=true`，支持快速“校准完成”）
- 数据审核（`/api/audit/pending`、`/api/audit/my`、`/api/audit`、`approve/reject`）
- 审核详情对比（字段级差异 + 原文 JSON 对比）
- 审核分页筛选（历史记录分页、状态/类型/关键词服务端筛选参数）
- 审核筛选持久化（切页/重进保留筛选词、页码、页签）
- 审核筛选按用户隔离（不同账号筛选与页码缓存互不干扰）
- 审核筛选降级提示（服务端筛选失败时自动回退本地筛选当前页并提示）
- 审核筛选降级收敛（仅筛选参数不支持时才降级；鉴权/网络错误直接提示）
- 列表请求防并发覆盖（同模块多次触发请求时仅最新结果生效）
- 列表稳定行标识（业务主键优先，避免分页/刷新后列表复用错位）
- 我的文件（`/api/files`、`/api/files/breadcrumb`、`/api/files/{id}/download`）
- 文件预览临时文件清理（关闭预览后自动删除临时下载文件）
- 底部模块导航（台账/校准/待办/审核/更多，四大模块均可用）
- 文件预览（QuickLook）

## 基线版本

- iOS Deployment Target: `26.0`
- Xcode 基线: `26`（建议 26.0+）

## 目录结构

- `project.yml`: XcodeGen 工程定义
- `Sources/`: iOS 源码
- `scripts/build_ipa.sh`: 归档与导出 IPA 脚本
- `ExportOptions.plist`: IPA 导出参数模板

## 在 Mac 上生成 Xcode 工程

1. 安装 Xcode（26+）
2. 安装 XcodeGen

```bash
brew install xcodegen
```

3. 生成工程

```bash
cd ios-app
xcodegen generate
```

4. 打开工程并设置签名

- 打开 `MetrologyiOS.xcodeproj`
- `Signing & Capabilities` 里设置 Team
- 确认 `Bundle Identifier` 唯一

## 打包 IPA

```bash
cd ios-app
chmod +x scripts/build_ipa.sh
./scripts/build_ipa.sh MetrologyiOS Release
```

导出目录：`ios-app/build/export`

## GitHub 无签名 IPA 构建

仓库已提供工作流：`.github/workflows/ios-unsigned-ipa.yml`

- 工作流运行环境：`macos-15`，并自动选择 `Xcode_26*.app`

- 触发方式：
1. 任意分支推送且变更了 `**/project.yml`
2. 在 GitHub Actions 中手动执行 `iOS Unsigned IPA`

- 多应用支持：
1. 手动触发时填写 `app_dir` 指定目标目录（如 `ios-app` 或 `ios-app-2`）
2. 两个 iOS 应用可分别运行两次工作流
3. `scheme` 可留空（自动读取目标目录 `project.yml` 的 `name`），也可手动覆盖
4. `min_ipa_mb` 可设置最小未压缩 `.app` 体积阈值（默认 `1`，小于阈值工作流会失败）

- 构建产物（Artifacts）：
1. `<Scheme>-unsigned.ipa`
2. `<Scheme>.app.zip`
3. `checksums.txt`（SHA256）
4. `build-info.txt`（构建参数与 Xcode 版本）

- 本地同款无签名打包脚本：

```bash
cd <repo-root>
chmod +x scripts/build_unsigned_ipa.sh
./scripts/build_unsigned_ipa.sh ios-app MetrologyiOS Release
```

输出：`<app_dir>/build/artifacts/<Scheme>-unsigned.ipa`
可选：`MIN_APP_BUNDLE_SIZE_MB=1 ./scripts/build_unsigned_ipa.sh ios-app MetrologyiOS Release`
兼容旧参数：`MIN_IPA_SIZE_MB=1 ./scripts/build_unsigned_ipa.sh ios-app MetrologyiOS Release`

## 注意

- 由于 iOS 签名机制，必须在 **macOS + Xcode + Apple 开发者账号** 环境下导出可安装 `.ipa`。
- 无签名 IPA 主要用于测试分发流程或后续重签名，默认不能直接安装到真机。
- 默认后端地址在 `Sources/Resources/Info.plist`：`API_BASE_URL`。
- 如后端证书策略严格，请按生产要求收敛 `NSAppTransportSecurity`。
