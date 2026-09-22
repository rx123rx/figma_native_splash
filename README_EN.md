# figma_native_splash

Generate native Android, iOS and HarmonyOS splash screens — and desktop app icons — from **Figma design links**, with versioned snapshots, composition previews and offline generation.

中文版: [README.md](README.md)

> **Credentials:** `sync` and `icon sync` need a Figma Personal Access Token. Put it in the `figma_access_token` field at the top of the config file, or set the `FIGMA_ACCESS_TOKEN` environment variable (a non-empty variable wins). When neither is present the sync commands fail before any network call. See section 4 for details. `ExampleFileKey` and the node IDs below are placeholders — replace them with a board your token can access.

## What it does

| Capability | Description |
|---|---|
| Native splash screens | Exports a Figma board as three layers (**background + foreground + branding**) and writes Android, iOS and HarmonyOS resources, including Xcode references, `Info.plist` and `module.json5` wiring |
| Desktop app icons | The `icon` section generates launcher icons for all three platforms, including Android adaptive icons and API 33+ monochrome icons |
| Offline reproducibility | `sync` stores the design version, node bounds and asset hashes in a snapshot; `create` / `check` / `preview` never touch the network afterwards |
| Predictable changes | `create --dry-run` prints the plan first; same-name resources with different content, and manually edited tool files, always raise an error instead of being overwritten |

It does **not** modify your design files, guess visual intent, create a Flutter project, or add missing Android/iOS/HarmonyOS platform folders.

## The flow in 60 seconds

```text
figma_splash.yaml ──sync──▶ .figma_splash/ snapshot ──create──▶ android/ ios/ ohos resources
   the only file you write      network once, pins version        offline after that
```

| Step | Command | Purpose | Network | Writes |
|---|---|---|---|---|
| 1 | `sync` | Download the design and save the snapshot; native projects untouched | yes | snapshot only |
| 2 | `create --dry-run` | Preview the files that would change | no | no |
| 3 | `create` | Generate resources and wire them into the native projects | no | yes |
| 4 | `check` | Verify integration, snapshot integrity and conflicts; good for CI | no | no |

Run them as `dart run figma_native_splash:<command>`, e.g. `dart run figma_native_splash:sync`. Desktop icons use the same verbs with an `icon` prefix (`icon sync`, `icon create`, `icon check`, `icon preview`) — see section 5.

## Contents

- [1. Installation and requirements](#1-installation-and-requirements)
- [2. Configuration file structure](#2-configuration-file-structure)
- [3. Figma design requirements](#3-figma-design-requirements)
- [4. Commands, flags and credentials](#4-commands-flags-and-credentials)
- [5. Desktop app icons](#5-desktop-app-icons)
- [6. Generated output and platform differences](#6-generated-output-and-platform-differences)
- [7. Snapshots, output files and updates](#7-snapshots-output-files-and-updates)
- [8. Troubleshooting](#8-troubleshooting)
- [9. Development, validation and publishing](#9-development-validation-and-publishing)
- [Appendix A: full configuration reference](#appendix-a-full-configuration-reference)

If you just want it running: **read sections 1 and 2**. Come back to Appendix A when you need the meaning of a specific field.

## 1. Installation and requirements

Add the package to your Flutter app's `pubspec.yaml`:

```yaml
dev_dependencies:
  figma_native_splash: ^0.1.0
```

When working from local sources next to the app:

```yaml
dev_dependencies:
  figma_native_splash:
    path: ../figma_native_splash
```

Then run `flutter pub get` in the app root. Requires Dart **3.8.0 or newer, below 4.0.0**. With FVM, replace `dart` / `flutter` below with `fvm dart` / `fvm flutter`.

| Task | What you need |
|---|---|
| Syncing designs (`sync`) | Network, a Figma Personal Access Token with `file_content:read`, and access to the target file |
| Offline generation (`create` / `check` / `preview`) | Only Dart, the config, the saved snapshot and the native project files |
| Building the result | The platform toolchains; Android requires min API 24, HarmonyOS requires a Flutter OHOS engine exposing `FlutterPage` |

## 2. Configuration file structure

Everything comes from one file in your app root: **`figma_splash.yaml`**. It has four levels: **root → the `icon` / `splash` sections → each section's `figma` source and `platforms` scope → optional paths and platform switches**. Most projects only need two things: the Figma link and `platforms`.

### 2.1 The whole structure at a glance

```text
figma_splash.yaml
├── figma_access_token: ""          # optional; non-empty FIGMA_ACCESS_TOKEN wins
├── schema_version: 1               # optional, currently only 1 is accepted
│
├── icon:                           # desktop app icon, read by the icon commands
│   ├── figma: <board link>         # required; may also be written as url + nodes
│   │                               # default layer names: icon/background, icon/foreground, icon/monochrome
│   ├── platforms: [android, ios, ohos]
│   ├── resource_prefix: figma_icon
│   ├── background_color: "#FFFFFF" # required when the artwork has transparent pixels
│   ├── android: { adaptive: true, monochrome: false }
│   └── project: { android_res, android_manifest, ios_runner, ohos_main, ohos_app_scope, ohos_ability }
│
└── splash:                         # native launch screen, read by sync/create/check/preview
    ├── figma:
    │   ├── phone: <link, or url + nodes>               # required
    │   │   └── nodes: { background, foreground, branding }  # optional
    │   └── tablet: <same shape as phone>              # optional; reuses the phone art when omitted
    ├── platforms: [android, ios, ohos]                # list only the platforms you actually have
    ├── resource_prefix: figma_splash
    ├── background_color: "#FFFFFF"
    ├── ohos: { app_splash: false }
    └── project: { android_res, ios_runner, ohos_main, ohos_page, ohos_ability }
```

### 2.2 `icon` and `splash` are independent

| | `icon` section | `splash` section |
|---|---|---|
| Controls | The launcher/home screen icon | The system launch window shown at cold start |
| Commands | `icon sync` / `icon create` / `icon check` / `icon preview` | `sync` / `create` / `check` / `preview` |
| Minimum required | `icon.figma` | `splash.figma.phone` |
| Shared root fields | `figma_access_token`, `schema_version` | same |
| Not shared | `platforms`, `resource_prefix`, `background_color` and `project` **apply per section and are never inherited** | same |

The two `resource_prefix` values must differ. Delete a whole section when you only use the other feature.

### 2.3 Three ways to start

**Splash screens only** (the common case — keep `platforms` to the platforms you have):

```yaml
splash:
  figma:
    phone: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2"
  platforms: [android, ios]
```

**Desktop icons only** (square board without transparent areas):

```yaml
icon:
  figma: https://www.figma.com/design/ExampleFileKey/AppIcon?node-id=2-1
  platforms: [android, ios]
```

**Both features** (`schema_version` appears once):

```yaml
schema_version: 1
icon:
  figma: https://www.figma.com/design/ExampleFileKey/AppIcon?node-id=2-1
  platforms: [android, ios]
splash:
  figma:
    phone: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2"
  platforms: [android, ios]
```

When the board already uses the conventional layer names you never need `nodes`. Add `nodes` only for legacy boards whose layer names you cannot change.

### 2.4 Which field should I change?

| Goal | Change |
|---|---|
| Skip HarmonyOS (no `ohos/` folder) | `platforms: [android, ios]` — write it in each section you use |
| Add a tablet board | Add `splash.figma.tablet`; omitting it reuses the phone art |
| Keep existing layer names | `nodes: { background: "10:1", ... }` |
| Rename generated resources | `resource_prefix` (renaming after the first generation is rejected — migrate first) |
| Non-standard native folders | `project.*` — all paths are relative to `--project` |
| Transparent artwork renders with the wrong backdrop | `background_color`, `"#RRGGBB"` only |
| Show a HarmonyOS promo view before the first Flutter frame | `splash.ohos.app_splash: true` |
| Android icons without separate layers | `icon.android.adaptive: false` |

### 2.5 Your first run

```bash
# 1. Read the design, save assets, snapshot and previews; native projects untouched.
dart run figma_native_splash:sync

# 2. List the native files that would be added or removed; writes nothing.
dart run figma_native_splash:create --dry-run

# 3. Apply the result; iOS storyboards are registered in Resources automatically.
dart run figma_native_splash:create

# 4. Verify the integration and detect conflicts; writes nothing.
dart run figma_native_splash:check
```

Running `check` / `create` / `preview` before the first `sync` reports a missing snapshot and **never downloads anything**. Changing links, node mappings or adding a tablet board requires a new `sync`; changing colours, platforms or the HarmonyOS switch only requires `create`.

## 3. Figma design requirements

Every board must contain the following visible layers. Names are case-sensitive; a role may be nested inside the board but must resolve to exactly one node:

```text
Launch screen (Frame / Component / Instance)
├── splash/background
├── splash/foreground
└── splash/branding
```

- **Background**: its transformed absolute bounds must cover the whole board; gradients and glows belong inside that container. Prefer stretchable gradients and avoid baking text or logos into the background.
- **Foreground**: headline plus decorations as one group; the container must include every effective pixel so nothing is clipped.
- **Branding**: logo, name and tagline as one group, placed near the bottom.
- System bars are drawn by the OS. Never put clocks, status bars or home indicators into the three roles — hide reference artwork instead.
- Draw at logical sizes, e.g. 375×812 for phones and 834×1194 for tablets; do not confuse 3x pixel sizes with logical board sizes. Assets are exported at 3x and fonts are not required on the machine.
- Phone and tablet counterparts must share the same aspect ratio. iOS verifies the ratio of foreground and branding and rejects large differences.
- Rotated and mirrored containers are supported: positions use transformed absolute bounds while the PNGs come straight from Figma. Exported aspect must match those bounds, and the background must still cover the board.
- Hidden or duplicated role containers, off-board node mappings and mismatched background bounds are errors. Explicit nodes must be visible descendants of that board.
- Only Design files (`/design/`, `/file/`) are supported — not FigJam, Slides, Make or share redirects. Branch links use the branch file key; node IDs accept `1-2` or `1:2`.

The tool only reads Figma. It never renames layers, edits designs or guesses roles from pixels.

## 4. Commands, flags and credentials

### The four splash commands

| Command | Network | Writes | Purpose |
|---|---|---|---|
| `sync` | yes | snapshot, previews | Download assets, pin the file version, store bounds and hashes |
| `check` | no | no | Validate snapshot, project structure, integration and conflicts |
| `create` | no | native files, manifests | Generate every enabled platform; never signs, installs or publishes the app |
| `preview` | no | preview images | Re-render composition previews from the stored snapshot |

A passing `check` means generation is up to date — not that the app compiles. `check` succeeds even when ordinary assets need regeneration, but returns a non-zero exit code when an iOS storyboard is missing from Resources or `Info.plist` does not point at the generated storyboard. Use `create --dry-run` → `create` → `check` when integrating for the first time.

### Flags

| Flag | Commands | Required / default | Behavior when omitted |
|---|---|---|---|
| `--project` | all | optional, current directory | Base path for every in-project path; accepts another app's absolute path |
| `--config` | all | optional, `figma_splash.yaml` | Relative to the project root; a missing file is an error, `pubspec.yaml` is never searched |
| `--platform` | `create`, `check` | optional, none | All enabled platforms are processed; only one of `android`, `ios`, `ohos` at a time, and it must be enabled in the YAML |
| `--dry-run` | `sync`, `create`, `preview` | optional, off | Compute and print the plan without writing; `sync` still needs the network and the token |
| `--help` / `-h` | all | optional | Print help without reading config or network |

`sync` and `preview` reject `--platform` — they work on the complete snapshot. There is no `--all`, platform list or `--remove`. The icon commands are documented in section 5. Expected configuration, network and file errors exit with code `2`; `0` means the command completed.

```bash
dart run figma_native_splash:create --platform=ios
dart run figma_native_splash:check --platform=ios
dart run figma_native_splash:create --config=config/splash.yaml --dry-run
dart run figma_native_splash:create --project=/path/to/app
```

Or install it globally:

```bash
dart pub global activate figma_native_splash
figma_native_splash sync --project=/path/to/app
figma_native_splash create --project=/path/to/app
```

### Credentials

`sync` and `icon sync` share one token, resolved in this order:

1. A non-empty `FIGMA_ACCESS_TOKEN` environment variable.
2. The top-level `figma_access_token` config value.
3. Neither present: fail before any network call, leaving the snapshot untouched.

Values are trimmed. The config field may be omitted or `""`, but not `null`, a number or a boolean. `create`, `check` and `preview` never require or validate a token. A failed authentication does not silently fall back to another credential.

Expired tokens, missing scopes or inaccessible files surface as HTTP 401/403. The tool never logs in interactively or reads browser sessions, and the token is not attached to asset download URLs. Tokens are not written to snapshots, resources or previews and do not affect source hashes, so rotating a token does not require regenerating anything.

To share the main config, keep `figma_access_token: ""` and use the environment variable, or copy the file into a Git-ignored local config and pass `--config=figma_splash.local.yaml` consistently.

HTTP 429 means rate limiting; the reported `Retry-After` is included in the error and there is no background retry loop. A failed sync never replaces an existing snapshot with partial data.

## 5. Desktop app icons

Launcher icons are unrelated to the launch-window icon. **`sync` / `create` / `check` / `preview` handle splash screens only**; the `icon …` commands handle desktop icons. A splash-only project can omit the entire `icon` section, and icon commands never touch storyboards, Android `LaunchTheme`, HarmonyOS `startWindowIcon` or `startWindowBackground`.

### Minimal icon configuration

```yaml
icon:
  figma: https://www.figma.com/design/ExampleFileKey/AppIcon?node-id=2-1
  platforms: [ios]
```

`splash.figma.phone` and the icon layers are not needed here. The board must be square without transparent areas, otherwise set `icon.background_color` explicitly. A single `figma_splash.yaml` can hold both features side by side.

### Required fields

Every icon command requires `icon.figma`; the object form requires `url`. All other fields are optional, but the defaults enable all three platforms and Android adaptive icons, which implies three platform projects and aligned foreground/background layers. If you only target iOS or HarmonyOS, set `icon.platforms` and no Android layers are needed. Optional `nodes` does not mean the corresponding design layers are optional.

### Board and export rules

- The icon board must be square, 256–4096 logical px (1024 recommended), exported to at least 1024×1024 PNG. Rectangular artwork is rejected rather than stretched.
- For plain icons the whole board export is used; keep visible guides, annotations or monochrome helpers out of the board.
- Android adaptive icons need `icon/background` and `icon/foreground`. Both outer containers must share position and size with the board, and the foreground keeps transparent padding. The tool preserves transformed alignment and never re-centres or crops a role.
- In adaptive mode every platform's full-colour icon is composited from those two layers; keep `icon/monochrome` and other helper layers out of it. The whole-board PNG is still saved for reference.
- Adaptive layers map to 108×108 dp; keep important artwork inside the central 66 dp safe circle because launchers may mask it. The tool does not shrink logos based on image content — verify edges with previews and devices.
- `icon/monochrome` must have a transparent background and non-transparent outline. RGB is normalised to white and alpha is preserved; fully transparent or fully opaque layers are rejected, and a black-on-white image cannot replace a transparency mask.
- iOS and HarmonyOS receive opaque full-colour icons without pre-baked corners. iOS dark/tinted icons, Liquid Glass layered icons, per-flavor Android configuration and HarmonyOS layered icons are not supported.

### Icon commands and files

```bash
fvm dart run figma_native_splash:icon sync
fvm dart run figma_native_splash:icon create --dry-run
fvm dart run figma_native_splash:icon create
fvm dart run figma_native_splash:icon check
fvm dart run figma_native_splash:icon preview
fvm dart run figma_native_splash:icon create --platform=ios
```

Drop `fvm` when you do not use FVM. After a global install you can also run `figma_native_splash icon create`; from sources the entry point is `dart run bin/icon.dart create`.

The icon `check` is stricter than the splash check: any pending asset, manifest or integration change exits with code `2` and asks you to run `icon create`; a clean state returns `0`. Nothing is auto-fixed and nothing is written.

```text
.figma_splash/
├── icon_snapshot/             # icon source, version, SHA-256 and raw PNGs
├── icon_previews/             # full-colour icon and Android crop hints, not device screenshots
├── generated_icon_android.json
├── generated_icon_ios.json
└── generated_icon_ohos.json
```

- Commit config, icon snapshot, manifests and native resources; ignore `.figma_splash/icon_previews/` in the app.
- Re-run `icon sync` after changing links, node mappings or the set of Android layers; a composited background colour change only needs `icon create`.
- Android: 48/72/96/144/192 px plain icons, 432 px adaptive layers, resource qualifiers for API 26/33.
- iOS: all required iPhone/iPad sizes (including 167 px) plus a 1024 px store icon; the AppIcon build setting and asset catalogue membership are updated automatically.
- HarmonyOS: 1024 px PNGs in AppScope and the selected module, updating `app.icon` and the chosen Ability icon; package name, version, permissions and signing are untouched.
- Conflicting or manually edited files are never overwritten. Turning `adaptive`/`monochrome` off cleans up the generated resources the tool owns; removing a platform from `platforms` does not delete existing resources there.
- Other tools' configuration (`flutter_launcher_icons`, legacy icons) is never removed — verify the real icons first, then clean up manually.

## 6. Generated output and platform differences

| Platform | Result and adaptation |
|---|---|
| iOS | Layered launch storyboard per phone/tablet idiom, wired into the Xcode project automatically |
| Android API 24–30 | Layered drawables selected by window metrics; API 26+ uses percentage placement, 24/25 a dp fallback |
| Android API 31+ | System solid background with centred icon and bottom branding; a 1152×1152 safe canvas and 800×320 branding image are generated, placement is decided by the system |
| HarmonyOS | Updates the system launch icon and background of one Ability by default; `app_splash: true` additionally wires an ArkUI layered view sized to the available window |

The iOS project must resolve to exactly one `.xcodeproj` and one application target. Targets using `fileSystemSynchronizedGroups` must be converted to plain groups in Xcode first.

Current template limits:

- Only phone and tablet entry points exist: no dedicated landscape board, arbitrary layer list or animation configuration. Landscape reuses the same composition and scales the foreground by available height.
- Legacy Android backgrounds fill the window; iOS/HarmonyOS scale-and-crop. Foreground and branding always keep their aspect ratio.
- Light and dark mode share one set of artwork — there is no separate dark link or override field.
- Android 12+ cannot render a full gradient poster inside the system launch window.
- The HarmonyOS promo view has no fixed duration, and disabling it does not guarantee the system window stays until the first Dart frame. Toggling it off only cleans up the tool's own wiring; your custom builders stay untouched.
- Static Figma coordinates cannot express folding, split-screen or rotation intent; templates cover it, so always verify on devices or emulators afterwards.

## 7. Snapshots, output files and updates

```text
figma_splash.yaml
.figma_splash/
├── snapshot/
│   ├── snapshot.json       # source nodes, Figma version, layout and SHA-256
│   ├── phone/              # reference render and the three role PNGs
│   └── tablet/             # downloaded only when tablet is configured
├── generated_android.json
├── generated_ios.json
├── generated_ohos.json
└── previews/               # phone/tablet portrait, landscape, small window and Android 12 previews
```

Commit the config, snapshot, manifests and native files so CI can generate offline. Previews can be ignored: `.figma_splash/previews/`. Do not add these native assets to Flutter `assets`, otherwise they may be bundled twice.

- Multiple boards of one Figma file are pinned to a single file version and exported at that version; phone and tablet may come from different files.
- Re-run `sync` after changing links, node mappings or adding/removing the tablet board. Colour, platform selection and `splash.ohos.app_splash` changes only need `create`.
- A hash mismatch blocks generation; never hand-edit the PNGs inside the snapshot.
- Regenerating identical content produces no file differences.
- Same-name resources with different content and manually edited generated files raise errors instead of being overwritten. Migrate deliberately before changing the resource prefix or project paths — the tool is not a rename utility.
- Only the launch-related fields of project files are updated. Other splash plugins, legacy resources, signing settings and app code are left alone.

## 8. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No design snapshot | Run `sync` in the correct project directory |
| Board or layer not found | Check file access, `node-id`, hidden layers and whether the mapping belongs to that board |
| Matched zero or several layers | Use exact `splash/<role>` names, or pin a unique node ID |
| Background bounds mismatch | Wrap the background in a container that covers the board; a lone glow is not the background |
| iOS aspect ratio differs | Organise phone and tablet foreground/branding with the same aspect ratio, then sync again |
| Missing LaunchTheme / Info.plist / Ability | Check `platforms` and `project` paths; create the native platform first |
| Generated file conflict | Restore tool files after keeping your edits, or pick another resource prefix before the first generation |
| Leftover HarmonyOS promo references | Look for manual imports and builder references before deleting code that is still used |
| Preview differs from the device | Previews are schematic: no real system bars, launch animation or per-device constraints |

## 9. Development, validation and publishing

```bash
dart pub get
dart format --output=none --set-exit-if-changed lib bin test tool example
dart analyze
dart test
dart pub publish --dry-run
```

The same sequence is wrapped by `tool/publish.dart`, which additionally checks the release version against `CHANGELOG.md`, placeholder URLs, `PUB_HOSTED_URL` and whether the version already exists on pub.dev:

```bash
dart run tool/publish.dart                # checks only, nothing uploaded
dart run tool/publish.dart --publish      # re-runs the checks, then dart pub publish
dart run tool/publish.dart --force        # skips pub's confirmation, CI only
```

Pub warnings (for example a missing `homepage`/`repository`) do not stop the script, real validation errors and failed checks do. Uploads always target `https://pub.dev`; a local `PUB_HOSTED_URL` mirror is overridden for the upload command only.

The complete configuration sample lives in this README and in the standalone examples: [example/figma_icon.yaml](example/figma_icon.yaml), [example/figma_splash.yaml](example/figma_splash.yaml). Tests keep both in sync and verify that every field parses. See [example/example.dart](example/example.dart) for calling the API without Figma access.

[Validation scope](doc/validation.md) · [Publishing notes](doc/publishing.md) · [MIT License](LICENSE)

This tool has no official affiliation with Figma, Flutter or any platform vendor.

## Appendix A: full configuration reference

Copy this block as-is and delete the parts you do not need. Every field is annotated with whether it is required, its default and what happens when it is omitted. Also available as [example/figma_splash.yaml](example/figma_splash.yaml) and [example/figma_icon.yaml](example/figma_icon.yaml).

```yaml
# Optional. Shared Figma Personal Access Token for `sync` and `icon sync`.
# A non-empty FIGMA_ACCESS_TOKEN environment variable wins; otherwise this value is used.
# Omitted or "": use the environment variable only. When both are empty, sync fails before any request.
# Never commit a real token; keep "" in shared configs. Strings only — null, numbers and booleans are rejected.
figma_access_token: ""

# Optional config format version (not the package version), default 1. Only the integer 1 is accepted.
schema_version: 1

# Required for the icon commands; delete this whole section when you only generate splash screens.
icon:
  # Required. Either a URL string, or { url + nodes } as below.
  # Must include node-id; omitting it is an error and never falls back to the splash board.
  figma:
    # Required when using the object form. Points at a square Frame/Component/Instance.
    url: https://www.figma.com/design/ExampleFileKey/AppIcon?node-id=2-1
    # Optional. Omitted or {}: resolve icon/background, icon/foreground and icon/monochrome by name.
    # Partial mappings are allowed; once an ID is given, that role no longer falls back to its name.
    nodes:
      background: "2:2"    # required when icon.android.adaptive is true
      foreground: "2:3"    # required when icon.android.adaptive is true
      monochrome: "2:4"    # required when icon.android.monochrome is true

  # Optional non-empty list, default [android, ios, ohos]; not inherited from splash.platforms.
  platforms: [android, ios, ohos]

  # Optional string, default figma_icon, independent of splash.resource_prefix.
  # Lowercase start, then lowercase letters, digits and underscores; cannot equal the splash prefix.
  # Renaming after generating is rejected; migrate the old resources and manifests first.
  # Also used as the iOS .appiconset name and the AppIcon build setting value.
  resource_prefix: figma_icon

  # Optional string, no default backdrop and never inherited from splash.background_color.
  # Accepts quoted #RRGGBB only. Required when full-colour or adaptive artwork has transparent pixels.
  background_color: "#FFFFFF"

  # Optional mapping; Android layered artwork is optional when Android is disabled.
  android:
    # Optional boolean, default true — quotes or null are errors.
    # true: generate API 26+ adaptive icons from aligned background/foreground layers.
    # false: plain density icons only, which API 26+ also uses.
    adaptive: true
    # Optional boolean, default false. true requires adaptive=true plus a separate transparency outline
    # and generates API 33+ monochrome icons. Switching back to false cleans up generated monochrome resources.
    monochrome: false

  # Optional mapping. All paths are relative to --project, never to the YAML file.
  # In-project relative paths only: absolute paths, escaping ../ and symlinked outputs are rejected.
  project:
    android_res: android/app/src/main/res
    android_manifest: android/app/src/main/AndroidManifest.xml
    ios_runner: ios/Runner
    ohos_main: ohos/entry/src/main
    ohos_app_scope: ohos/AppScope
    ohos_ability: EntryAbility

# Required for the splash commands; delete it when you only generate icons.
splash:
  # Required mapping; omitting it, null or a wrong type is an error. Figma is the only source — no local input.
  figma:
    # Required for splash generation; accepts a URL string or { url + nodes }.
    phone:
      # Required inside the object form. Must be an https://figma.com or https://www.figma.com
      # design/file link with node-id, pointing at a Frame, Component or Instance board.
      url: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2"
      # Optional mapping for legacy boards you cannot rename.
      # Omitted or {}: every role resolves by name (splash/background, splash/foreground, splash/branding).
      nodes:
        background: "10:1"   # must cover the whole board
        foreground: "10:2"   # headline and decorations; no status bar screenshots
        branding: "10:3"     # bottom logo, name and tagline

    # Optional, same shape as phone. Omitted: reuse the phone art and reference size.
    tablet:
      url: "https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-3"
      nodes:
        background: "20:1"   # belongs to the tablet board, not the phone board
        foreground: "20:2"
        branding: "20:3"

  # Optional non-empty list, default [android, ios, ohos]. Duplicates are merged.
  platforms: [android, ios, ohos]

  # Optional string, default figma_splash. Lowercase letters, digits and underscores after a lowercase start.
  resource_prefix: figma_splash

  # Optional quoted #RRGGBB, default "#FFFFFF". No #RGB, no alpha, no gradients.
  background_color: "#FFFFFF"

  # Optional mapping; omitting it behaves like app_splash: false.
  ohos:
    # Optional boolean, default false. true additionally wires FlutterPage.splashScreenView.
    app_splash: false

  # Optional mapping; standard Flutter projects can omit it entirely.
  project:
    android_res: android/app/src/main/res
    ios_runner: ios/Runner
    ohos_main: ohos/entry/src/main
    ohos_page: ohos/entry/src/main/ets/pages/Index.ets
    ohos_ability: EntryAbility
```

### Required versus optional

| Field | Type | Required | Behavior when omitted |
|---|---|---|---|
| `figma_access_token` | string | no | Use the environment variable; sync fails only if both are empty |
| `schema_version` | integer | no | Uses `1`, the only accepted value |
| `splash` | map | **yes for splash commands** | Error; icon-only usage may omit it |
| `splash.figma` | map | **yes** | Error |
| `splash.figma.phone` | URL string or map | **yes for splash commands** | Error; the tablet board never substitutes for it |
| `splash.figma.phone.url` | string | **yes in object form** | Error; not needed with the URL shorthand |
| `splash.figma.phone.nodes.*` | node ID strings | no | Resolve `splash/background`, `splash/foreground`, `splash/branding` by name |
| `splash.figma.tablet` | URL string or map | no | Reuse the phone design; no tablet board is downloaded |
| `splash.platforms` | non-empty list | no | `android`, `ios`, `ohos` |
| `splash.resource_prefix` | string | no | `figma_splash` |
| `splash.background_color` | colour string | no | `"#FFFFFF"` |
| `splash.ohos.app_splash` | boolean | no | `false`, no second-stage promo view |
| `splash.project.*` | relative paths / string | no | Standard Flutter folders, `EntryAbility` |
| `icon` | map | **yes for icon commands** | Error; splash-only usage may omit it |
| `icon.figma` | map | **yes** | Error |
| `icon.figma.url` | string | **yes in object form** | Error |
| `icon.figma.nodes.*` | node ID strings | no | Resolve `icon/background`, `icon/foreground`, `icon/monochrome` by name |
| `icon.platforms` | non-empty list | no | `android`, `ios`, `ohos` |
| `icon.resource_prefix` | string | no | `figma_icon` |
| `icon.background_color` | colour string | no | No backdrop; transparent artwork then fails |
| `icon.android.adaptive` / `monochrome` | booleans | no | `true` / `false` |
| `icon.project.*` | relative paths / string | no | Standard Flutter and HarmonyOS locations |

**Optional fields do not mean optional design layers.** `background`, `foreground` and `branding` must all exist in the board even when only the HarmonyOS system window is generated; `nodes` merely changes how a role is located.

Root only accepts `figma_access_token`, `schema_version`, `icon` and `splash`, and each present section must be a map. Each command validates unknown fields, wrong types and explicit `null` within its own scope. To get a default, delete the field instead of writing empty values, `"false"` or `null`. `nodes: {}`, `ohos: {}` and `project: {}` are valid and mean "use defaults"; `platforms: []` is not.
