# Changelog

See [CHANGELOG.md](CHANGELOG.md) for the Chinese version.

## 0.1.3

- Splash roles can now reference **off-board artwork**: `splash.figma.<board>.nodes.<role>` accepts an `{ id, x, y }` object where `x`/`y` place the asset's top-left corner inside the board (design points). This suits reusable design-system layers such as a shared brand lockup; `icon` node mappings still accept plain ID strings only.
- Off-board artwork shared by phone and tablet is requested and downloaded once per file and written to both role assets.
- Nodes without an explicit position keep the previous relative-bounds behaviour, so `sourceHash` for existing configs is unchanged and no re-sync is needed for this feature alone.
- Document the option in both READMEs, the Figma template guide and error messages, with new parsing and sync tests.

## 0.1.2

- Re-encode Android and HarmonyOS splash PNGs from decoded pixels. Snapshot originals may carry `pHYs` / `sRGB` / `gAMA` / `tEXt` metadata or use an indexed palette, which made per-platform output diverge; the same layer now yields identical bytes on both platforms, with no pixel changes.
- Format `AndroidManifest.xml` and Android `styles.xml` in project style: 4-space indent, one attribute per line when an element has more than three, and a space before `/>`. The previous 2-space, single-line output rewrote the whole manifest on every run.
- Use tab indentation for the iOS `Info.plist` (Xcode's own style) instead of reflowing it to 2 spaces.
- Write iOS image set and app icon `Contents.json` in Xcode's `"key" : value` format, record `author` as `xcode`, and include only slots that have a file. Empty 1x/2x slots that Xcode adds on open used to show up as Unassigned with asset warnings.
- Add `formatXml`, `encodeAssetCatalogContents`, `imageSetContents` and `normalizePng` helpers with tests.

## 0.1.1

- Restructure the README: document the `FIGMA_ACCESS_TOKEN` requirement at the top and rewrite it around install, Figma preparation, configuration, commands and per-platform output, with the full configuration structure and field reference.
- Add `README_EN.md` mirroring the Chinese documentation.
- Add `tool/publish.sh`, which runs dependency resolution, format checks, analysis, tests and a pub.dev dry run in one pass; `--publish` uploads to `https://pub.dev` while dependency downloads keep using the local mirror.
- Fix the pub.dev publishing setup: drop the extra topic and pin `publish_to` with the repository URL.

## 0.1.0

- Support a top-level `figma_access_token` setting; a non-empty environment variable wins, icons and splash screens share it, and the credential is never written into generated output.
- Split the configuration into top-level `icon` and `splash` sections, each managing its Figma source, platforms, colors and project paths. Configuration format version is 1.
- Add independent Figma app icon `sync`, `create`, `check` and `preview` commands, Android adaptive and monochrome resources, iPhone/iPad AppIcon catalogs and HarmonyOS icon integration.
- Fix missing iOS Xcode Resources registration: `create` now patches `project.pbxproj` idempotently and `check` reports incomplete storyboard integration.
- Generate native Android, iOS and HarmonyOS splash resources from Figma design links.
- Accept rotated and mirrored layers using transformed bounds and exported PNGs, retaining coverage and aspect checks.
- Support named design layers and explicit node mappings for phone and tablet frames.
- Save versioned, integrity-checked design snapshots for offline generation.
- Provide `sync`, `check`, `create`, `preview`, per-platform generation and dry-run commands.
- Make the HarmonyOS app splash opt-in and clean up generated layers when disabled.
- Protect manually edited outputs and preserve unrelated host application configuration.
- Document every configuration field, its defaults and omission behavior.
