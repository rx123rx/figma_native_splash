# figma_native_splash

从 **Figma 设计链接**生成 Android、iOS、鸿蒙原生启动图和桌面 App 图标。支持手机/平板适配、构图预览和离线生成。

> **同步凭据：** 可在配置文件最前面的 `figma_access_token` 填写 Figma Personal Access Token，也可设置环境变量 `FIGMA_ACCESS_TOKEN`（非空时优先）。仅 `sync` 和 `icon sync` 需要凭据；两处都未提供时会在联网前报错。Token 需要 `file_content:read` 权限，且所属账号有权访问目标文件。填写真实 Token 的配置不要提交到 Git 或分享；团队共享配置建议留空，通过环境变量提供凭据。离线 `create` / `check` / `preview` 无需 Token。

> 示例中的 `ExampleFileKey`、节点 ID 为占位值，请替换成有访问权限的真实 Figma 画板。

## 1. 安装与使用条件

在 Flutter 项目的 `pubspec.yaml` 中添加依赖：

```yaml
dev_dependencies:
  figma_native_splash: ^0.1.0
```

使用本地源码时，在 App 与本工具目录相邻的情况下可以配置：

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

配置按功能分成顶层 **`icon`**（桌面图标）和 **`splash`**（启动图）两段。每段自己的 `figma`、`platforms`、`resource_prefix`、`background_color` 和 `project` 独立生效，互不继承。只用其中一种功能时，可以省略另一段。两种功能一起使用时，可直接复制[完整配置示例](#complete-config)，`schema_version` 只写一次。

```yaml
figma_access_token: "" # 选填；可在本地填写，非空环境变量优先
schema_version: 1
icon:
  figma: https://www.figma.com/design/ExampleFileKey/AppIcon?node-id=2-1
  platforms: [android, ios]
  android:
    adaptive: false
splash:
  figma:
    phone: https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2
    tablet: https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-3
  platforms: [android, ios]
```

上例图标使用无透明区域的完整正方形画板；启动图仍按三个角色分层。命令保持不变，普通命令读取 `splash`，`icon` 命令读取 `icon`。

在 App 根目录新建 **`figma_splash.yaml`**。如果设计稿使用约定图层名，最少只需要手机链接：

```yaml
splash:
  figma:
    # 必填：指向启动图画板，必须带 node-id。不能只提供整个文件的链接。
    phone: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2"
```

上述最小配置默认启用三个平台。**普通 Flutter 项目没有鸿蒙目录时，必须把 `splash.platforms` 改成实际存在的平台**，例如：

```yaml
splash:
  figma:
    phone: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2"
  platforms: [android, ios]
```

在 YAML 最前面的 `figma_access_token` 填写 Token，或在终端 / CI 密钥管理中设置 `FIGMA_ACCESS_TOKEN`。非空环境变量优先；空白值视为未提供。不要将真实凭据提交到 Git。登录 Figma 网页或编辑器不会自动为命令行提供 Token。

```bash
# 1. 联网读取设计，保存快照、素材和构图预览；不修改原生工程。
dart run figma_native_splash:sync

# 2. 查看预计修改/删除的原生文件及 Xcode 接入；不写文件。
dart run figma_native_splash:create --dry-run

# 3. 应用生成结果，自动注册 iOS Storyboard 到 Resources。
dart run figma_native_splash:create

# 4. 检查实际接入与输出冲突；不写文件。
dart run figma_native_splash:check
```

首次 `sync` 之前执行 `check/create/preview` 会提示缺少快照，**不会自行联网下载**。修改设计后再次主动执行 `sync`，再生成、检查 diff 并运行 App 验收。

<a id="complete-config"></a>

## 3. 完整配置示例：icon + splash

下面是一份完整的 `figma_splash.yaml`，同时包含桌面图标和手机/Pad 启动图的全部配置项，可整段复制。每项都注明必填性、默认值和省略行为。

请替换演示链接与节点 ID，并在两段中分别选择实际存在的平台；图层已按约定命名时，删除相应 `nodes` 映射即可。只使用一种功能时可删除另一整段。示例开启 Android 自适应图标，需要图标稿提供对齐的背景和前景图层；只有完整正方形图标稿时将 `icon.android.adaptive` 设为 `false`。

<!-- BEGIN COMPLETE CONFIG -->
```yaml
# 选填，供 icon sync 和 sync 共用的 Figma Personal Access Token。
# 非空环境变量 FIGMA_ACCESS_TOKEN 优先；未设置或为空时使用本项。
# 省略或 ""：仅使用环境变量；两处都没有 Token 时，同步会在联网前报错。
# create/check/preview 不需要 Token。必须为字符串，不接受 null、数字或布尔值。
# 填写真实 Token 后不要提交此文件到 Git；共享配置保留空字符串。
figma_access_token: ""

# 选填，配置格式版本（不是 App 或插件版本），默认 1。
# 当前只接受整数 1；省略时按当前格式解析，其他值或 null 报错。
schema_version: 1

# 图标命令必填，映射；只使用启动图命令时可省略整个 icon。
icon:
  # 必填，可用 URL 字符串简写，或下方 url + nodes 对象。
  # 必须带 node-id；省略时报错，不会从 splash 截取图标。
  figma:
    # 对象写法下必填；指向图标的正方形 Frame/Component/Instance。
    url: https://www.figma.com/design/ExampleFileKey/AppIcon?node-id=2-1
    # 选填。省略或 {}：按 icon/background、icon/foreground、icon/monochrome 查找。
    # 可以部分映射；指定 ID 后不再按名称回退。节点必须是画板内可见后代。
    # 按约定命名的设计稿应删除这些演示映射。
    nodes:
      # 选填；Android adaptive=true 时对应的背景图层必需。
      background: "2:2"
      # 选填；Android adaptive=true 时对应的前景图层必需。
      foreground: "2:3"
      # 选填；Android monochrome=true 时对应的单色轮廓图层必需。
      monochrome: "2:4"

  # 选填非空列表；默认 [android, ios, ohos]；不继承 splash.platforms。
  # 可用值只有 android/ios/ohos；重复项合并，[]、null 或未知平台报错。
  # 不存在对应平台工程时应移除该平台。不会自动创建原生工程。
  platforms: [android, ios, ohos]

  # 选填字符串，默认 figma_icon，与 splash.resource_prefix 独立。
  # 必须小写字母开头，后续仅小写字母、数字、下划线。
  # 不能与启动图前缀相同；生成后改名会被拒绝，需先迁移旧资源和清单。
  # 同时作为 iOS .appiconset 名称及 AppIcon 编译设置值。
  resource_prefix: figma_icon

  # 选填字符串，无默认底色，且不继承启动图 background_color。
  # 仅接受带引号的 #RRGGBB。
  # 全彩图标/自适应背景含透明像素时必填，否则生成失败。
  # 不透明素材可省略。只填补透明区域，不覆盖已有颜色。
  # 自适应前景和单色轮廓保留透明通道，不使用这个底色合成。
  background_color: "#FFFFFF"

  # 选填映射；未启用 Android 时，不要求 Android 的分层素材。
  android:
    # 选填布尔值，默认 true；"true"、null 等报错。
    # true：生成 API 26+ 自适应图标，必须有对齐的背景/前景图层。
    # false：只生成普通多密度图标；API 26+ 也使用普通图标回退。
    adaptive: true
    # 选填布尔值，默认 false。
    # true：要求 adaptive=true 及独立透明轮廓，生成 API 33+ 单色图标。
    # false/省略：不生成单色图标；从 true 改 false 后 create 会清理工具生成的单色资源。
    monochrome: false

  # 选填映射。以下路径都相对于 --project，不相对于 YAML 所在目录。
  # 必须是工程内的相对路径；拒绝绝对路径、越界和输出符号链接。
  # 各路径独立取默认值，修改资源目录不会自动推导其他路径。
  project:
    # 选填，默认 android/app/src/main/res；普通与自适应图标的资源根目录。
    android_res: android/app/src/main/res
    # 选填，默认 android/app/src/main/AndroidManifest.xml。
    # Android 启用时必须存在，需有唯一 application。
    # 修改 application icon/roundIcon；有独立图标的 launcher activity/alias 也一起更新。
    android_manifest: android/app/src/main/AndroidManifest.xml
    # 选填，默认 ios/Runner；AppIcon 写入其 Assets.xcassets。
    # 同级必须有唯一 .xcodeproj；Target 选择和不支持的自动同步 Group 规则同第 6 节。
    # 自动接入资产目录，并更新该应用所有构建配置的 AppIcon 名称，含已有条件化设置。
    ios_runner: ios/Runner
    # 选填，默认 ohos/entry/src/main；必须有 module.json5。
    # 在指定 Ability 上更新 icon，其他 Ability 和启动窗口配置保持原值。
    ohos_main: ohos/entry/src/main
    # 选填，默认 ohos/AppScope；必须有 app.json5 的 app 对象。
    # 在其 resources/base/media 下生成应用图标，并更新 app.icon。
    ohos_app_scope: ohos/AppScope
    # 选填，默认 EntryAbility；必须唯一匹配 module.abilities 内的 name。
    # 不存在或有多个匹配时报错，不会自动选第一个。
    ohos_ability: EntryAbility

# 启动图命令必填；只使用 icon 命令时可省略整个 splash。
splash:
  # 必填，映射。splash.figma 省略、为 null 或类型错误：报错。
  # 这里只支持 Figma 来源，没有本地图片输入配置。
  figma:
    # 生成启动图时必填；仅使用 icon 命令时不需要 phone。接受「URL 字符串」或下方这种「url + nodes 映射」。
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
    # 同级目录必须存在唯一 .xcodeproj；工具会自动修改其中的 project.pbxproj。
    # 多应用 Target 时优先选择与该目录同名的应用 Target，否则必须只有一个应用 Target。
    # 缺少工程或 Target 无法唯一定位：报错，不只写图片后假定接入成功。
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
<!-- END COMPLETE CONFIG -->

### 必填性与省略行为速查

| 配置项 | 类型 | 是否必填 | 省略时的行为 |
|---|---|---|---|
| `figma_access_token` | 字符串 | 否 | 使用环境变量；两处均为空时仅同步命令报错，离线命令可用 |
| `schema_version` | 整数 | 否 | 使用 `1`，只支持此版本 |
| `splash` | 映射 | **启动图命令必填** | 报错；仅图标命令可省略 |
| `splash.figma` | 映射 | **是** | 报错 |
| `splash.figma.phone` | URL 字符串或映射 | **启动图命令必填** | 报错；独立 icon 命令无需此项 |
| `splash.figma.phone.url` | 字符串 | **对象写法时是** | 报错；URL 简写不需要这个键 |
| `splash.figma.phone.nodes` | 映射 | 否 | 三个角色都按约定名字查找 |
| `splash.figma.phone.nodes.background` | 节点 ID 字符串 | 否 | 查找 `splash/background` |
| `splash.figma.phone.nodes.foreground` | 节点 ID 字符串 | 否 | 查找 `splash/foreground` |
| `splash.figma.phone.nodes.branding` | 节点 ID 字符串 | 否 | 查找 `splash/branding` |
| `splash.figma.tablet` | URL 字符串或映射 | 否 | 复用手机设计；不额外下载 Pad 画板 |
| `splash.figma.tablet.url` | 字符串 | **提供 tablet 对象时是** | 报错 |
| `splash.figma.tablet.nodes` 及三个子项 | 映射 / 节点 ID 字符串 | 否 | 与手机规则一致，但在 Pad 画板内查找 |
| `splash.platforms` | 非空列表 | 否 | 处理 `android`、`ios`、`ohos` |
| `splash.resource_prefix` | 字符串 | 否 | 使用 `figma_splash` |
| `splash.background_color` | 颜色字符串 | 否 | 使用 `"#FFFFFF"` |
| `splash.ohos` | 映射 | 否 | 鸿蒙使用默认行为 |
| `splash.ohos.app_splash` | 布尔值 | 否 | `false`，不添加第二阶段宣传图 |
| `splash.project` | 映射 | 否 | 使用标准 Flutter 原生目录 |
| `splash.project.android_res` | 相对路径字符串 | 否 | `android/app/src/main/res` |
| `splash.project.ios_runner` | 相对路径字符串 | 否 | `ios/Runner` |
| `splash.project.ohos_main` | 相对路径字符串 | 否 | `ohos/entry/src/main` |
| `splash.project.ohos_page` | 相对路径字符串 | 否 | `ohos/entry/src/main/ets/pages/Index.ets` |
| `splash.project.ohos_ability` | 字符串 | 否 | `EntryAbility` |

**配置项选填不代表对应设计图层可以缺失。** `background`、`foreground`、`branding` 三个角色都必须在设计稿中存在，即使只生成鸿蒙系统启动窗口。`nodes` 只是改变角色的查找方式。

根节点仅接受 `figma_access_token`、`schema_version`、`icon`、`splash`，出现的功能段必须是映射。各命令校验自身配置范围内的未知字段、错误类型和显式 `null`。启动图命令不处理 `icon` 配置，图标命令不要求 `splash.figma.phone`。需要默认值时请删除该字段，不要写空值、`"false"` 或 `null`。`nodes: {}`、`ohos: {}`、`project: {}` 合法，分别表示使用默认查找和默认设置；`platforms: []` 不合法。

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

`check` 通过只表示生成条件满足，不代表已编译或运行通过。`check` 发现普通素材待更新仍可返回成功；iOS Storyboard 未注册到应用 Resources，或 Info.plist 未指向生成的启动图时返回非零退出码，并提示执行 `create`。首次接入请按 `create --dry-run` → `create` → `check` 执行。缺少工程文件、快照损坏或冲突也会失败。

### 命令行参数

| 参数 | 适用命令 | 必填 / 默认值 | 省略或使用时的行为 |
|---|---|---|---|
| `--project` | 全部 | 选填，当前工作目录 | 所有项目内路径据此解析；可指定另一个工程的绝对路径 |
| `--config` | 全部 | 选填，`figma_splash.yaml` | 相对于项目根目录；省略但文件不存在时会报错，不会查找 pubspec.yaml 中的配置 |
| `--platform` | `create`、`check` | 选填，无 | 省略则处理 YAML 中所有平台；一次仅能指定 `android`、`ios` 或 `ohos`，且必须已在 YAML 启用 |
| `--dry-run` | `sync`、`create`、`preview` | 选填，默认关闭 | 计算并打印变化但不写文件；`sync` 仍访问网络、需要 Token；对只读的 `check` 没有额外效果 |
| `--help` / `-h` | 全部 | 选填 | 显示帮助，不读取项目配置或访问网络 |

`sync/preview` 不接受 `--platform`，它们针对完整设计快照。工具不支持 `--all`、平台列表参数或 `--remove`。独立的 App 图标命令见第 9 节。预期配置/网络/文件错误通常以退出码 `2` 结束；退出码 `0` 表示该命令完成。

```bash
# 仅生成并检查 iOS
dart run figma_native_splash:create --platform=ios
dart run figma_native_splash:check --platform=ios

# 配置文件放在项目内 config/ 目录；路径仍以项目根目录为基准
dart run figma_native_splash:create --config=config/splash.yaml --dry-run

# 指定目标 App 的路径
dart run figma_native_splash:create --project=/path/to/app
```

也可全局安装后使用：

```bash
dart pub global activate figma_native_splash
figma_native_splash sync --project=/path/to/app
figma_native_splash create --project=/path/to/app
```

### Token 配置与环境变量

`sync` 和 `icon sync` 共用一份 Token，按以下顺序选择：

1. 非空的 `FIGMA_ACCESS_TOKEN` 环境变量。
2. 顶层 `figma_access_token` 配置值。
3. 两处都未提供：在联网前报错，不写快照。

会去除首尾空白。配置字段可以省略或写 `""`，但不能写 `null`、数字、布尔值；环境变量优先不代表忽略配置类型错误。`create`、`check`、`preview` 不要求有效 Token，也不会联网验证它。认证失败不会自动改用另一份 Token。

过期、缺少权限或无法访问文件通常导致 HTTP 401/403。工具不会交互登录或读取浏览器会话，下载导出图片时不会携带 Figma Token。Token 不写入生成资源、快照或预览，也不参与来源哈希；更换 Token 无需重新生成现有资源。

如果希望共享主配置，可保持其中的 `figma_access_token: ""` 并使用环境变量；也可复制为已加入 `.gitignore` 的本地配置，通过 `--config=figma_splash.local.yaml` 指定，后续生成命令使用同一配置。

HTTP 429 表示限流，错误中会显示服务端提供的 `Retry-After` 信息；工具不会在后台无限重试。同步失败时不会用部分下载结果替换现有快照。

## 6. 生成行为与平台差异

| 平台 | 原生结果与适配方式 |
|---|---|
| iOS | 根据手机/平板尺寸适配分层启动图，自动接入 Xcode 工程 |
| Android API 24–30 | 分层启动图，按窗口尺寸适配背景、主视觉和底部品牌 |
| Android API 31+ | 系统纯色背景、居中图形和底部品牌；自动生成 1152×1152 安全图标画布与 800×320 品牌图，实际位置和大小由系统控制 |
| 鸿蒙 | 默认只更新指定 Ability 的系统启动图标和底色；`app_splash: true` 时额外接入按可用窗口尺寸调整的 ArkUI 分层图 |

iOS 工程需能唯一确定 `.xcodeproj` 和应用 Target。使用 `fileSystemSynchronizedGroups` 的 Target 需先在 Xcode 中转换为普通 Group。

当前模板的边界：

- 只有手机和 Pad 两份设计入口，没有横屏独立稿、任意图层或交互动画配置。横屏使用相同构图并根据可用高度缩小前景。
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
- 改链接、节点映射或增删 Pad 后必须重新 `sync`。只改颜色、平台选择或 `splash.ohos.app_splash` 后直接 `create` 即可。
- 图片哈希不符时拒绝生成；不要手工替换快照里的 PNG。
- 重复生成相同内容不产生额外文件差异。
- 首次遇到同名但不同内容的资源、已生成资源被手动修改，都会报错，不静默覆盖。更改资源前缀/工程目录时应先明确迁移旧接入和资源，工具不是通用重命名器。
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

## 9. 桌面 App 图标

图标功能与系统启动窗口的图标是两回事。**普通 `sync/create/check/preview` 命令仅处理启动图**；`icon sync/create/check/preview` 才处理桌面图标。只配置启动图的项目可省略整个 `icon` 段。图标命令不会改启动 Storyboard、Android LaunchTheme、鸿蒙 `startWindowIcon` 或 `startWindowBackground`。

### 最小图标配置

例如仅生成 iPhone/iPad 图标：

```yaml
icon:
  figma: https://www.figma.com/design/ExampleFileKey/AppIcon?node-id=2-1
  platforms: [ios]
```

这时不需要 `splash.figma.phone`，也不需要图标分层。画板必须是无透明区域的正方形，否则需要明确配置 `icon.background_color`。多平台项目可在同一个 `figma_splash.yaml` 中同时保留 `splash.figma.phone`、`splash.figma.tablet`、`icon.figma` 和两组设置。

### 完整配置与必填关系

图标的全部字段已放在第 3 节的[完整配置示例](#complete-config)中，与 `splash` 一起展示；无需手动拼接两个示例。只需要图标时也可参考 [example/figma_icon.yaml](example/figma_icon.yaml)。

**必填关系：** 图标命令总是要求 `icon.figma`；其对象写法要求 `url`。所有其他图标字段都可省略，但默认启用三端和 Android 自适应图标，因此默认情况下需要三端工程与前景/背景图层。只有 iOS 或鸿蒙时，直接设置 `icon.platforms` 即可，不需要 Android 图层。`nodes` 字段选填不等于相应的设计图层选填。

### Figma 画板与导出规则

- 图标主画板必须正方形，逻辑边长 256～4096，推荐 1024。按固定版本导出到至少 1024×1024 的 PNG；拒绝矩形素材，不拉伸成正方形。
- 仅生成普通图标时直接使用整个画板导出结果；不要在画板内放可见的参考线、标注或单色辅助层。
- 启用 Android 自适应图标时，需要 `icon/background` 和 `icon/foreground`。两层外层容器必须与主画板同位置、同尺寸；前景内部保留透明留白。程序保留变换后的坐标对齐，不对角色自动居中或重新裁掉留白。
- 自适应模式下，所有平台的全彩图标由指定背景和前景合成，避免 `icon/monochrome` 或其他辅助层混入全彩图标。整体画板 PNG 同步保存为参考。
- Android 的自适应层对应 108×108 dp，重要图形应位于中心直径 66 dp 的安全区域；系统可能裁成圆形、圆角方形等。工具不会根据图像语义自动缩小 Logo，需要通过预览和设备验收检查边缘。
- `icon/monochrome` 使用透明背景和非透明轮廓。工具将 RGB 统一为白色、保留 alpha，由桌面决定主题颜色；全透明或完全不透明的图层会报错，不能用白底黑图代替透明蒙版。
- iOS/HarmonyOS 输出使用不透明全彩图，不预先烘焙圆角。当前不支持 iOS 独立深色/着色图标、Liquid Glass 分层图标、Android 多 flavor 分别配置或 HarmonyOS 分层图标。

### 命令与文件

```bash
# 同步图标，不修改原生工程；Token 可来自环境变量或配置文件。
fvm dart run figma_native_splash:icon sync

# 离线查看资源和原生接入变化。
fvm dart run figma_native_splash:icon create --dry-run

# 离线生成，然后检查文件与工程接入是否已经同步。
fvm dart run figma_native_splash:icon create
fvm dart run figma_native_splash:icon check

# 从快照重新生成图标构图/裁切预览。
fvm dart run figma_native_splash:icon preview

# 仅生成已在 icon.platforms 中启用的 iOS。
fvm dart run figma_native_splash:icon create --platform=ios
```

未使用 FVM 时把 `fvm dart` 换成 `dart`。全局安装后也可执行 `figma_native_splash icon create`；源码入口是 `dart run bin/icon.dart create`。

| 参数 | 是否必填 / 默认值 | 用途及省略行为 |
|---|---|---|
| `--project` | 选填，当前目录 | 所有工程内路径的基准 |
| `--config` | 选填，`figma_splash.yaml` | 相对于工程根目录；文件不存在会报错 |
| `--platform` | 选填，无 | 仅适用于 create/check；省略处理全部 icon.platforms，一次只能选一个已启用的平台 |
| `--dry-run` | 选填，关闭 | sync/create/preview 计算结果但不写入；sync 仍联网并要求 Token；check 本身只读 |
| `--help` / `-h` | 选填 | 不读配置、不联网，显示帮助 |
| `FIGMA_ACCESS_TOKEN` | 选填；sync 需要至少一种凭据来源 | 非空时覆盖配置的 figma_access_token；只发给 Figma API，不发给图片下载地址 |

图标 `check` 比启动图的预生成检查更严格：图标素材、清单或原生接入有任何待更新项都返回退出码 `2`，提示先执行 `icon create`；同步且无冲突返回 `0`。错误不自动修复，不会写入工程。

输出与状态：

```text
.figma_splash/
├── icon_snapshot/             # 图标来源、版本、SHA-256 与原始 PNG
├── icon_previews/             # 全彩图标与 Android 裁切示意，非设备截图
├── generated_icon_android.json
├── generated_icon_ios.json
└── generated_icon_ohos.json
```

- 建议提交配置、图标快照、生成清单和原生资源；将 `.figma_splash/icon_previews/` 加入应用 `.gitignore`。
- 改图标链接、节点映射，或改变需要下载的 Android 图层时重新 `icon sync`；只改合成底色直接 `icon create`。
- Android 普通图标生成 48/72/96/144/192 px；自适应图层为 432 px，API 26/33 分别使用资源限定符。
- iOS 生成 iPhone/iPad 所需图标规格（包括 iPad 167 px）及 1024 px 商店图；自动设置 AppIcon 名称并确保资产目录参与应用 Resources。
- 鸿蒙在 AppScope 和指定模块各生成 1024 px PNG，分别更新 app.icon 与指定 Ability.icon；不修改包名、版本、权限或签名。
- 生成文件有冲突或被手改时拒绝覆盖。关闭 adaptive/monochrome 并重新生成后，清理该平台本工具管理的过期资源；从 platforms 删掉整个平台不会自动删除该平台的已有资源。
- 不自动移除 `flutter_launcher_icons`、旧桌面图标或其他工具配置。迁移应用时，先验证三端实际图标，再移除旧依赖和不再使用的资源。
