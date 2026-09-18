## 0.1.0

- 支持顶层 figma_access_token 配置；非空环境变量优先，图标与启动图共用，凭据不写入生成结果。
- 配置按顶层 icon / splash 分别管理 Figma 来源、平台、颜色与工程路径，配置格式版本为 1。

- Add independent Figma app icon sync/create/check/preview commands, Android adaptive and monochrome resources, iPhone/iPad AppIcon catalogs and HarmonyOS icon integration.

- Fix missing iOS Xcode Resources registration; create now patches project.pbxproj idempotently and check reports incomplete storyboard integration.

- Generate native Android, iOS and HarmonyOS splash resources from Figma design links.
- Accept rotated and mirrored layers using transformed bounds and exported PNGs, retaining coverage and aspect checks.
- Support named design layers and explicit node mappings for phone and tablet frames.
- Save versioned, integrity-checked design snapshots for offline generation.
- Provide sync, check, create, preview, per-platform generation and dry-run commands.
- Make the HarmonyOS app splash opt-in and clean up generated layers when disabled.
- Protect manually edited outputs and preserve unrelated host application configuration.
- Document every configuration field, its defaults and omission behavior.
