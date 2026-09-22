# 更新日志

英文版本见 [CHANGELOG_EN.md](CHANGELOG_EN.md)。

## 0.1.1

- 重构 README：开头给出 `FIGMA_ACCESS_TOKEN` 必读说明，按「安装 → 准备 Figma → 编写配置 → 执行命令 → 平台产物」重写使用流程，并补齐配置文件结构与字段说明。
- 新增英文文档 `README_EN.md`，与中文文档内容对应。
- 新增统一发布脚本 `tool/publish.sh`：一次执行依赖解析、格式检查、静态分析、测试与 pub.dev dry run；`--publish` 时上传地址固定为 `https://pub.dev`，依赖下载仍走本机镜像。
- 修正 pub.dev 发布配置：移除多余 topic，补充 `repository` 并固定 `publish_to`。

## 0.1.0

- 支持顶层 `figma_access_token` 配置；非空环境变量优先，图标与启动图共用，凭据不写入生成结果。
- 配置按顶层 `icon` / `splash` 分别管理 Figma 来源、平台、颜色与工程路径，配置格式版本为 1。
- 新增独立的 Figma 应用图标 `sync` / `create` / `check` / `preview` 命令，支持 Android 自适应与单色图标资源、iPhone/iPad AppIcon 目录以及鸿蒙图标接入。
- 修复 iOS 启动图未注册到 Xcode Resources 的问题：`create` 现在以幂等方式改写 `project.pbxproj`，`check` 会报告 storyboard 接入不完整。
- 从 Figma 设计链接生成 Android、iOS、鸿蒙原生启动图资源。
- 支持旋转与镜像图层：按变换后的边界与导出 PNG 处理，保留覆盖率与宽高比检查。
- 支持命名设计图层，以及手机与平板画板的显式节点映射。
- 保存带版本与完整性校验的设计快照，用于离线生成。
- 提供 `sync`、`check`、`create`、`preview`、分平台生成与 dry-run 命令。
- 鸿蒙应用启动图改为可选开启，关闭时清理已生成图层。
- 保护手工改动的产物，并保留宿主工程中无关的配置。
- 逐字段说明每个配置项、默认值与省略时的行为。
