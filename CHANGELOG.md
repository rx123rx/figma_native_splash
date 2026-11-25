# 更新日志

英文版本见 [CHANGELOG_EN.md](https://github.com/rx123rx/figma_native_splash/blob/main/CHANGELOG_EN.md)。

## 0.1.4

- 新增 Agent Skill：[skills/figma-native-splash/SKILL.md](https://github.com/rx123rx/figma_native_splash/blob/main/skills/figma-native-splash/SKILL.md)。Claude Code、Codex、Cursor 等支持 `SKILL.md` 的 AI 代理安装后，可按 skill 指引完成依赖添加、`figma_splash.yaml` 编写、`sync` / `preview` / `create` / `check` 与图标命令，并覆盖图层命名、Token、iOS 接入以及鸿蒙（OHOS）`startWindowIcon` / `startWindowBackground`、`ohos.app_splash` 宣传图、`ohos/AppScope` 与 Ability 图标等出错时的修复路径。
- 新增 `skills/figma-native-splash/references/config-reference.md`，汇总配置字段、默认值与省略行为，供 AI 按需加载。
- 中英文 README 增加「用 AI 自动接入」小节，给出 `npx skills add rx123rx/figma_native_splash` 与手动复制两种安装方式；文档中的仓库内相对链接改为 GitHub 绝对链接，在 pub.dev 上同样可点。
- 新增 `test/skill_test.dart`，校验 Skill 的 frontmatter、目录名、相对链接以及 README 的安装说明，避免文档失配。

## 0.1.3

- 启动图角色支持引用**画板外素材**：`splash.figma.<画板>.nodes.<角色>` 可以写成 `{ id, x, y }` 对象，用 `x`/`y` 指定素材左上角在画板内的位置（设计点）。适合引用设计系统里单独维护的品牌组合等可复用图层；`icon` 的节点映射仍只接受字符串 ID。
- 同一文件内被手机、平板共用的画板外素材只请求、下载一次，并写入两端的素材路径。
- 未指定位置的节点仍按原有相对边界计算，旧配置的 `sourceHash` 保持不变，升级后无需因本功能重新 sync。
- 补充 README、英文文档、模板规范与错误提示，新增画板外素材的配置和同步测试。

## 0.1.2

- Android 与鸿蒙的启动图 PNG 统一重新编码：快照原图可能带 `pHYs` / `sRGB` / `gAMA` / `tEXt` 元数据或是索引色，直接落盘会让各端产物格式不一致；现改为按解码后的像素重新编码并清空 `tEXt`，保证同一图层在两端得到相同字节，像素无损。
- `AndroidManifest.xml`、Android `styles.xml` 改为按工程风格格式化：4 空格缩进、属性超过 3 个时逐个换行、自闭合标签在 `/` 前保留空格。此前默认的 2 空格 + 单行属性会让每次生成都把整份 manifest 重排。
- iOS `Info.plist` 改用 Tab 缩进（Xcode 标准），不再被重排成 2 空格。
- iOS 图片集与图标集的 `Contents.json` 改用 Xcode 的 `"key" : value` 格式，`author` 记为 `xcode`，并只写入带文件的槽位。此前 Xcode 打开工程后补出的空 1x/2x 槽位会显示为 Unassigned 并产生资源警告。
- 新增 `formatXml`、`encodeAssetCatalogContents`、`imageSetContents`、`normalizePng` 工具函数及对应测试。

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
