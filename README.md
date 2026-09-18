# figma_native_splash

Generate native Android, iOS, and HarmonyOS splash screens from Figma designs, with versioned snapshots and offline generation.

从 **Figma 设计链接**生成 Android、iOS、鸿蒙原生启动图的 Dart 命令行工具。支持「背景＋主视觉＋底部品牌」分层模板、手机/平板适配、设计快照、构图预览和生成文件冲突检查。工具不参与 App 运行，不需要 AI，也不依赖 Python 或其他启动图插件。

> 当前是首次公开发布准备版本。只有发布成功后才能从 pub.dev 下载；发布前可使用本地 path 依赖。本文中的 `ExampleFileKey`、节点 ID 为演示占位值，请替换成有访问权限的真实 Figma 画板。

## 1. 安装与使用条件

pub.dev 发布后的依赖声明：

```yaml
dev_dependencies:
  figma_native_splash: ^0.1.0
```

发布前，在 App 与本工具目录相邻时可以使用：

```yaml
dev_dependencies:
  figma_native_splash:
    path: ../figma_native_splash
```

在 Flutter 工程根目录执行 `flutter pub get`。要求 Dart **3.8.0 或以上、低于 4.0.0**；使用 FVM 的项目将下文 `dart` / `flutter` 命令分别替换为 `fvm dart` / `fvm flutter`。

- 同步设计需要网络、Figma Personal Access Token，以及该 Token 所属账号对文件的访问权限。Token 需要 `file_content:read` 权限。
- 离线生成只需要 Dart、配置、已下载的设计快照和目标原生工程文件。
- 编译/运行生成结果仍需要对应平台工具链。Android 最低支持 API 24；鸿蒙项目需要已集成提供 `FlutterPage` 的 Flutter OHOS 引擎。
- 工具不会创建 Flutter 工程，也不会自动添加不存在的 Android/iOS/鸿蒙平台。

## 2. 最小配置与首次运行

在 App 根目录新建 **`figma_splash.yaml`**。如果设计稿使用约定图层名，最少只需要手机链接：

```yaml
figma:
  # 必填：指向启动图画板，必须带 node-id。不能只提供整个文件的链接。
  phone: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2"
```

上述最小配置默认启用三个平台。**普通 Flutter 项目没有鸿蒙目录时，必须把 `platforms` 改成实际存在的平台**，例如：

```yaml
figma:
  phone: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2"
platforms: [android, ios]
```

在终端或 CI 密钥管理中设置 `FIGMA_ACCESS_TOKEN`，不要写入 YAML 或 Git。这个环境变量只在 `sync` 时需要；登录 Figma 网页或编辑器并不会自动为命令行提供 Token。

```bash
# 1. 联网读取设计，保存快照、素材和构图预览；不修改原生工程。
dart run figma_native_splash:sync

# 2. 离线检查配置、快照哈希、工程接入条件和文件冲突；不写文件。
dart run figma_native_splash:check

# 3. 查看预计修改/删除的原生文件；不写文件。
dart run figma_native_splash:create --dry-run

# 4. 应用生成结果。
dart run figma_native_splash:create
```

首次 `sync` 之前执行 `check/create/preview` 会提示缺少快照，**不会自行联网下载**。修改设计后再次主动执行 `sync`，再生成、检查 diff 并运行 App 验收。

## 3. 完整配置示例：每个选项都有注释

下面列出了所有受支持的 YAML 配置项。可以整段复制后替换链接和节点；不需要的选填项可删除。图层命名已符合约定时，建议删除 `nodes` 映射，避免复制演示 ID 后找不到图层。

<!-- BEGIN FULL CONFIG -->
```yaml
# 选填，整数，默认 1。目前只接受 1。
# 省略：按当前配置格式解析。填写其他数字、字符串或 null：报错。
schema_version: 1

# 必填，映射。整个 figma 省略、为 null 或类型错误：报错。
# 这里只支持 Figma 来源，没有本地图片输入配置。
figma:
  # 必填。接受「URL 字符串」或下方这种「url + nodes 映射」。
  # 省略 phone：报错，不会拿 tablet 自动代替手机稿。
  phone:
    # 对象写法下必填，非空字符串。
    # 必须是 https://figma.com 或 https://www.figma.com 的 design/file 链接，
    # 并带有 node-id；节点应为 Frame、Component 或 Instance 画板。
    # 省略/无 node-id/错误域名/错误类型：报错。
    url: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2"

    # 选填，映射；用于不想改图层名字的旧设计稿。
    # 省略 nodes 或传 {}：三个角色均按 splash/<角色名> 自动查找。
    # 可以只映射其中一个角色，其他角色仍按名称查找。
    # 一旦指定某个角色的 ID，就只按 ID 查找，不再回退到名字。
    nodes:
      # 选填，字符串节点 ID，支持 "10:1" 或 "10-1"。
      # 省略：查找唯一可见的 splash/background 图层。
      # 该图层必须属于当前画板，且容器边界覆盖整个画板。
      background: "10:1"

      # 选填，字符串节点 ID。
      # 省略：查找唯一可见的 splash/foreground 图层。
      # 导出主文案及装饰；图片保持宽高比，不能混入状态栏截图。
      foreground: "10:2"

      # 选填，字符串节点 ID。
      # 省略：查找唯一可见的 splash/branding 图层。
      # 导出底部 Logo、名称和标语；不填写 ID 不代表省略品牌图层。
      branding: "10:3"

  # 选填，类型和 phone 完全相同，支持 URL 简写或对象写法。
  # 省略：复用手机稿素材与参考尺寸；宽屏会适配，但不会凭空生成 Pad 设计，
  # 主视觉/品牌的最大参考宽度仍受手机稿限制。
  # 若提供 tablet，它的 url 在对象写法下必填，nodes 仍是选填。
  tablet:
    url: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-3"
    nodes:
      # 这三个节点必须属于 tablet 链接指向的画板，而不是手机画板。
      # 逐项省略时，分别回退为该画板内的 splash/background、
      # splash/foreground、splash/branding 名称查找。
      background: "20:1"
      foreground: "20:2"
      branding: "20:3"

# 选填，非空字符串列表，默认 [android, ios, ohos]。
# 仅接受 android、ios、ohos；重复项会合并。
# 省略：check/create 默认处理三个平台，缺少任意平台工程时会报错。
# 只有 Android/iOS 工程时请写 [android, ios]，只有鸿蒙则写 [ohos]。
# 此项控制原生生成范围，不减少 sync 下载的设计画板或图层。
platforms: [android, ios, ohos]

# 选填，非空字符串，默认 figma_splash。
# 只允许小写英文字母开头，后续为小写字母、数字、下划线。
# 用作生成的资源名及 iOS Storyboard 名字前缀，降低已有文件重名风险。
# 省略：使用 figma_splash。不能用包名中的点号、连字符或大写字母。
# 第一次生成后改这个值会被拒绝，需要先显式迁移旧资源与生成清单。
# 它不会修改 App 包名、Bundle ID、鸿蒙 builder 类名或快照目录。
resource_prefix: figma_splash

# 选填，字符串，默认 "#FFFFFF"。必须加引号，且仅接受 #RRGGBB。
# 省略：Android 12+ / 鸿蒙系统启动窗口使用白色底色，透明图层也以白色打底。
# 不会从 Figma 自动吸取颜色。Android 12+ 的系统窗口只能使用纯色背景。
# 同时用于部分平台启动区域/系统栏底色和构图预览，不会改 App 内主题。
# 不支持 #RGB、#AARRGGBB、透明色或渐变字符串。
background_color: "#FFFFFF"

# 选填，映射。省略整个 ohos 等价于 app_splash: false。
# platforms 未启用 ohos 时，该设置不产生鸿蒙文件。
ohos:
  # 选填，布尔值，默认 false；只能写 true/false，不能加引号。
  # false/省略：仅配置鸿蒙系统启动窗口，不添加第二阶段分层宣传图。
  # true：额外接入 FlutterPage.splashScreenView，在 Flutter 首帧前显示宣传图。
  # 不添加固定展示时长；系统窗口何时消失仍由系统和引擎控制。
  # 从 true 改成 false 并重新 create：清理本工具生成的 builder、引用及分层资源，
  # 保留系统图标和背景。项目原有自定义 builder 不会被关闭操作删除。
  app_splash: false

# 选填，映射；标准 Flutter 工程可以整个省略。
# 以下路径均相对于 --project 指定的项目根目录，而不是 YAML 文件所在目录。
# 路径必须为项目内的非空相对路径，不允许绝对路径、../ 越界或反斜杠。
# 工具拒绝经过符号链接的输出路径。
project:
  # 选填，默认 android/app/src/main/res。
  # Android 资源根目录；其中 values/styles.xml 必须有唯一 LaunchTheme。
  # 省略：使用标准路径。多 flavor 工程需要自行选择要修改的资源目录。
  android_res: android/app/src/main/res

  # 选填，默认 ios/Runner。
  # iOS Runner 目录；必须有 Info.plist，工具会写入其 Assets.xcassets / Base.lproj。
  # 省略：使用标准 Runner。不是 .xcodeproj 路径，也不是整个 ios 根目录。
  ios_runner: ios/Runner

  # 选填，默认 ohos/entry/src/main。
  # 鸿蒙模块 main 目录，必须包含 module.json5；媒体资源写入 resources/base。
  # 省略：使用标准 entry 模块。
  # 修改此项不会自动修改下面的 ohos_page，两项默认值彼此独立。
  ohos_main: ohos/entry/src/main

  # 选填，默认 ohos/entry/src/main/ets/pages/Index.ets。
  # app_splash=true 时必须存在，且包含唯一 FlutterPage({...}) 调用。
  # app_splash=false 的新工程可以没有此文件；关闭已有接入时会检查并移除本工具引用。
  # 省略：使用标准入口页。自定义模块/入口页时，应和 ohos_main 一起设置。
  ohos_page: ohos/entry/src/main/ets/pages/Index.ets

  # 选填，非空字符串，默认 EntryAbility。
  # 必须对应 module.json5 中可唯一定位的 Ability name；不是包名或文件路径。
  # 省略：查找 EntryAbility。找不到/不唯一：报错，不猜测使用其他 Ability。
  ohos_ability: EntryAbility
```
<!-- END FULL CONFIG -->

### 必填性与省略行为速查

| 配置项 | 类型 | 是否必填 | 省略时的行为 |
|---|---|---|---|
| `schema_version` | 整数 | 否 | 使用 `1`，只支持此版本 |
| `figma` | 映射 | **是** | 报错 |
| `figma.phone` | URL 字符串或映射 | **是** | 报错 |
| `figma.phone.url` | 字符串 | **对象写法时是** | 报错；URL 简写不需要这个键 |
| `figma.phone.nodes` | 映射 | 否 | 三个角色都按约定名字查找 |
| `figma.phone.nodes.background` | 节点 ID 字符串 | 否 | 查找 `splash/background` |
| `figma.phone.nodes.foreground` | 节点 ID 字符串 | 否 | 查找 `splash/foreground` |
| `figma.phone.nodes.branding` | 节点 ID 字符串 | 否 | 查找 `splash/branding` |
| `figma.tablet` | URL 字符串或映射 | 否 | 复用手机设计；不额外下载 Pad 画板 |
| `figma.tablet.url` | 字符串 | **提供 tablet 对象时是** | 报错 |
| `figma.tablet.nodes` 及三个子项 | 映射 / 节点 ID 字符串 | 否 | 与手机规则一致，但在 Pad 画板内查找 |
| `platforms` | 非空列表 | 否 | 处理 `android`、`ios`、`ohos` |
| `resource_prefix` | 字符串 | 否 | 使用 `figma_splash` |
| `background_color` | 颜色字符串 | 否 | 使用 `"#FFFFFF"` |
| `ohos` | 映射 | 否 | 鸿蒙使用默认行为 |
| `ohos.app_splash` | 布尔值 | 否 | `false`，不添加第二阶段宣传图 |
| `project` | 映射 | 否 | 使用标准 Flutter 原生目录 |
| `project.android_res` | 相对路径字符串 | 否 | `android/app/src/main/res` |
| `project.ios_runner` | 相对路径字符串 | 否 | `ios/Runner` |
| `project.ohos_main` | 相对路径字符串 | 否 | `ohos/entry/src/main` |
| `project.ohos_page` | 相对路径字符串 | 否 | `ohos/entry/src/main/ets/pages/Index.ets` |
| `project.ohos_ability` | 字符串 | 否 | `EntryAbility` |

**配置项选填不代表对应设计图层可以缺失。** `background`、`foreground`、`branding` 三个角色都必须在设计稿中存在，即使只生成鸿蒙系统启动窗口。`nodes` 只是改变角色的查找方式。

未知字段、错误类型、显式 `null` 会报错。需要默认值时请删除该字段，不要写空值、`"false"` 或 `null`。`nodes: {}`、`ohos: {}`、`project: {}` 合法，分别表示使用默认查找和默认设置；`platforms: []` 不合法。

## 4. Figma 设计稿要求

每个画板应包含以下可见图层，名称区分大小写，角色可以在画板内部嵌套，但必须匹配到唯一节点：

```text
Launch screen (Frame / Component / Instance)
├── splash/background
├── splash/foreground
└── splash/branding
```

- **背景**：变换后的绝对边界覆盖完整画板；渐变、光晕等可以放在容器内部。建议使用可拉伸渐变，避免将文字或 Logo 烘焙进背景。
- **主视觉**：文案、装饰作为一个整体，容器应包含所有有效像素，避免装饰/阴影超出边界后被裁掉。
- **品牌**：Logo、名称和标语作为一个整体，放在画板底部区域。
- 原生系统栏由系统绘制；不要把时间、状态栏和 Home 指示条放进三个角色。参考系统栏应在 Figma 中隐藏。
- 按逻辑尺寸作图，例如手机 375×812、平板 834×1194；不要把 3x 像素尺寸当成逻辑画板尺寸。工具按 3x 导出 PNG，不依赖开发机安装字体。
- 手机与 Pad 的对应前景图层应使用相同宽高比。iOS 会检查主视觉/品牌的比例差；超过容差会拒绝生成。
- 角色容器支持旋转和镜像：位置、尺寸使用变换后的绝对边界，PNG 使用 Figma 的导出结果，不再二次旋转或翻转。导出图片比例必须与该边界一致，否则报错；背景仍须覆盖完整画板。
- 隐藏、重复的角色容器、画板外节点映射、背景边界不符都会报错。显式指定的节点必须是该画板内的可见后代。
- 只支持 Design 文件（`/design/`、`/file/`），不支持 FigJam、Slides、Make 或分享链接跳转。分支链接会使用分支文件 ID；节点 ID 可使用 `1-2` 或 `1:2`。

更详细的设计约束见 [Figma 模板规范](doc/figma-template.md)。工具只读取 Figma，不重命名图层、不修改设计稿，也不根据图片内容猜测角色。

## 5. 命令、参数与环境变量

### 四个命令

| 命令 | 是否联网 | 是否写文件 | 用途 |
|---|---|---|---|
| `sync` | 是 | 快照与预览 | 从 Figma 下载素材，固定文件版本，保存节点边界和哈希 |
| `check` | 否 | 否 | 校验本地快照、工程结构、接入和文件冲突，报告待更新数量 |
| `create` | 否 | 原生工程与生成清单 | 按配置生成已启用平台；不签名、安装或发布 App |
| `preview` | 否 | 预览图 | 从已保存的快照重新生成构图示意 |

`check` 通过只表示生成条件满足，不代表已编译或运行通过。`check` 发现待更新文件仍可返回成功；真正缺少依赖文件、快照损坏或冲突时才返回非零退出码。

### 命令行参数

| 参数 | 适用命令 | 必填 / 默认值 | 省略或使用时的行为 |
|---|---|---|---|
| `--project` | 全部 | 选填，当前工作目录 | 所有项目内路径据此解析；可指定另一个工程的绝对路径 |
| `--config` | 全部 | 选填，`figma_splash.yaml` | 相对于项目根目录；省略但文件不存在时会报错，不会查找 pubspec.yaml 中的配置 |
| `--platform` | `create`、`check` | 选填，无 | 省略则处理 YAML 中所有平台；一次仅能指定 `android`、`ios` 或 `ohos`，且必须已在 YAML 启用 |
| `--dry-run` | `sync`、`create`、`preview` | 选填，默认关闭 | 计算并打印变化但不写文件；`sync` 仍访问网络、需要 Token；对只读的 `check` 没有额外效果 |
| `--help` / `-h` | 全部 | 选填 | 显示帮助，不读取项目配置或访问网络 |

`sync/preview` 不接受 `--platform`，它们针对完整设计快照。工具不支持 `--all`、平台列表参数或 `--remove`。预期配置/网络/文件错误通常以退出码 `2` 结束；退出码 `0` 表示该命令完成。

```bash
# 仅检查并生成 iOS
dart run figma_native_splash:check --platform=ios
dart run figma_native_splash:create --platform=ios

# 配置文件放在项目内 config/ 目录；路径仍以项目根目录为基准
dart run figma_native_splash:create --config=config/splash.yaml --dry-run

# 在工具源码目录操作另一个 App
dart run bin/figma_native_splash.dart create --project=/path/to/app
```

发布后也可全局激活：

```bash
dart pub global activate figma_native_splash
figma_native_splash sync --project=/path/to/app
figma_native_splash create --project=/path/to/app
```

### `FIGMA_ACCESS_TOKEN`

这是**唯一读取的凭据环境变量**，仅 `sync` 必需。省略或为空会在请求前报错；过期、缺少权限或无法访问文件通常导致 HTTP 401/403。工具不会交互登录、读取浏览器会话，也不会从配置文件查找 Token。下载导出图片时不会携带 Figma Token。

HTTP 429 表示限流，错误中会显示服务端提供的 `Retry-After` 信息；工具不会在后台无限重试。同步失败时不会用部分下载结果替换现有快照。

## 6. 生成行为与平台差异

| 平台 | 原生结果与适配方式 |
|---|---|
| iOS | 独立命名的 Storyboard 和图片集，更新 Info.plist 的 `UILaunchStoryboardName`；前景使用 Auto Layout、比例和安全区约束 |
| Android API 24–30 | 分层 drawable，通过窗口宽高资源限定符选择尺寸；API 26+ 使用百分比垂直位置，24/25 使用 dp 回退 |
| Android API 31+ | 系统纯色背景、居中图形和底部品牌；自动生成 1152×1152 安全图标画布与 800×320 品牌图，实际位置和大小由系统控制 |
| 鸿蒙 | 默认只更新指定 Ability 的系统启动图标和底色；`app_splash: true` 时额外接入按可用窗口尺寸调整的 ArkUI 分层图 |

当前模板的边界：

- 只有手机和 Pad 两份设计入口，没有横屏独立稿、任意图层或交互动画配置。横屏使用相同构图并根据可用高度缩小前景。
- iOS 按设备 idiom 选择图片，按窗口尺寸约束布局；Android/鸿蒙根据窗口宽度选择手机/宽屏素材。三端不是逐像素相同的布局引擎。
- Android 旧版背景铺满窗口；iOS/鸿蒙分层背景等比覆盖裁剪。主视觉和品牌始终保持比例。
- 深色和浅色使用同一套品牌素材，目前没有独立深色 Figma 链接或暗色覆盖字段。
- Android 12+ 无法通过系统启动窗口实现完整渐变宣传海报。
- 鸿蒙宣传图不添加固定展示时长；关闭它不保证系统窗口一直保留到 Dart 首帧。开关只清理本工具的接入，项目自定义 builder 需要自行处理。
- Figma 静态坐标无法完整表达折叠、分屏和横屏意图，工具用模板规则补足；生成后仍需真机/模拟器验收。

## 7. 快照、输出文件与更新策略

```text
figma_splash.yaml
.figma_splash/
├── snapshot/
│   ├── snapshot.json       # 来源节点、Figma 版本、布局和 SHA-256
│   ├── phone/             # 原始参考图及三个角色 PNG
│   └── tablet/            # 配置 tablet 时才下载
├── generated_android.json
├── generated_ios.json
├── generated_ohos.json
└── previews/              # 手机/Pad 横竖屏、小窗口及 Android 12 示意图
```

建议提交配置、快照、生成清单和原生文件，让构建机器离线生成。预览可加入 `.gitignore`：`.figma_splash/previews/`。这类原生素材不需要再加入 Flutter `assets` 声明，否则可能重复打包。

- 同一个 Figma 文件的多个画板固定到同一文件版本，再按该版本导出图片；手机和 Pad 可以来自不同文件。
- 改链接、节点映射或增删 Pad 后必须重新 `sync`。只改颜色、平台选择或 `ohos.app_splash` 后直接 `create` 即可。
- 图片哈希不符时拒绝生成；不要手工替换快照里的 PNG。
- 重复生成相同内容不产生额外文件差异。
- 首次遇到同名但不同内容的资源、已生成资源被手动修改，都会报错，不静默覆盖。更改资源前缀/工程目录时应先明确迁移旧接入和资源，工具不是通用重命名器。
- 先计算并检查全部选中平台，再写入；写入异常时尝试恢复原文件。它不提供进程崩溃或断电级事务保证。
- 工程配置只更新所需启动字段。不会自动删除其他启动图插件、旧资源、签名设置或业务代码。

## 8. 常见错误

| 提示 / 现象 | 原因与处理 |
|---|---|
| 没有设计快照 | 先在正确项目目录执行 `sync` |
| 找不到画板或图层 | 检查文件权限、node-id、隐藏图层和映射所在画板 |
| 匹配到 0 个或多个图层 | 使用精确的 `splash/<角色>` 名称，或指定唯一节点 ID |
| 背景容器边界不符 | 在 Figma 中用覆盖画板的容器包裹背景，不用孤立的光晕节点当整个背景 |
| iOS 对应图层比例不同 | 将手机/Pad 的主视觉、品牌按相同比例组织，再同步 |
| 找不到 LaunchTheme / Info.plist / Ability | 检查 `platforms` 和 `project` 路径，先创建对应原生工程 |
| 生成文件冲突 | 保留人工改动后恢复工具文件，或在首次接入前选择其他资源前缀 |
| 关闭鸿蒙宣传图提示剩余引用 | 检查手动改动的导入、builder 引用，避免删除仍被使用的代码 |
| 预览与设备不完全相同 | 预览是构图示意，不包含真实系统栏、启动动画和各系统约束 |

## 9. 开发、验证与发布

```bash
dart pub get
dart format --output=none --set-exit-if-changed lib bin test tool example
dart analyze
dart test
dart pub publish --dry-run
```

配置样例在本文维护，同时在 [example/figma_splash.yaml](example/figma_splash.yaml) 提供同内容文件；测试会检查两者一致，并验证所有字段可以被解析。无需访问 Figma 的代码调用示例见 [example/example.dart](example/example.dart)。

[验证范围](doc/validation.md) · [发布说明](doc/publishing.md) · [MIT License](LICENSE)

本工具与 Figma、Flutter 或平台厂商没有官方隶属关系。
