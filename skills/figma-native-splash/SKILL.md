---
name: figma-native-splash
description: >-
  Integrate figma_native_splash into a Flutter app: add the dev dependency, write figma_splash.yaml
  from Figma design links, and run sync/preview/create/check to generate Android, iOS and HarmonyOS
  native splash screens and launcher icons, with offline snapshots. Use when the user asks for a
  Figma-designed native launch or splash screen, or launcher/app icons, in a Flutter project, or
  mentions figma_native_splash, figma_splash.yaml, splash/background, splash/foreground,
  splash/branding or icon/foreground.
license: MIT
metadata:
  repository: https://github.com/rx123rx/figma_native_splash
  author: rx123rx
---

# figma_native_splash

A Dart dev dependency plus CLI for Flutter apps. It reads one board of a Figma **Design** file and
writes native splash screens and launcher icons into the existing Android, iOS and HarmonyOS
projects.

| Feature | Commands | Produces |
|---|---|---|
| Splash screen | `sync` / `preview` / `create` / `check` | Android LaunchTheme resources, iOS launch storyboard, HarmonyOS start-window assets |
| Desktop app icons | `icon sync` / `icon preview` / `icon create` / `icon check` | Android adaptive + monochrome icons, iOS AppIcon set, HarmonyOS app icon |

`sync` downloads the design once and stores a versioned snapshot under `.figma_splash/`; `preview`,
`create` and `check` then run offline. `create --dry-run` lists every planned change, and conflicts
or manually edited generated files raise errors instead of being overwritten.

It does **not**: create a Flutter project or missing platform folders, edit the Figma file, register
Flutter `assets:`, accept FigJam/Slides/Make links, support dark/tinted icon variants or landscape
boards, or replace other icon tooling.

## Before starting

1. The target is a Flutter app root (`pubspec.yaml`, plus at least one of `android/`, `ios/`, `ohos/`).
2. Dart `>=3.8.0 <4.0.0`. If `.fvmrc` exists, run `fvm flutter` / `fvm dart`; otherwise `flutter` / `dart`.
3. Only enable platforms whose directories exist: `ls -d android ios ohos 2>/dev/null`. Never create
   missing platform folders. Building the result later needs the platform toolchains (Android min
   API 24; HarmonyOS needs a Flutter OHOS engine exposing `FlutterPage`).
4. A Figma Design link: `https://www.figma.com/design/<fileKey>/...?node-id=<nodeId>` (also `/file/`).
   The `node-id` must point at a Frame, Component or Instance board. Branch links are fine.
   FigJam/Slides/Make links and share-link redirects are not supported.
5. `sync` and `icon sync` need a Figma Personal Access Token with the `file_content:read` scope and
   access to the file. Prefer the `FIGMA_ACCESS_TOKEN` environment variable. Never print, log or
   write a real token into a file that goes into git.
6. Ask the user for anything missing instead of inventing it: Figma link(s), whether a separate
   tablet board exists, target platforms, token availability. Do not guess layer names or roles.

## Workflow

### 0. Inspect the existing setup

```bash
ls -d android ios ohos 2>/dev/null
grep -n "figma_native_splash" pubspec.yaml
ls figma_splash.yaml .figma_splash 2>/dev/null
test -f .fvmrc && echo fvm
```

When a config and snapshot already exist, resume instead of restarting:

- Design link, node mapping, tablet board, or the set of downloaded Android icon layers changed →
  run `sync` again.
- Only `platforms`, `background_color`, resource paths or `ohos.app_splash` changed → run `create`.

### 1. Add the dependency

```bash
flutter pub add dev:figma_native_splash
flutter pub get
```

FVM: `fvm flutter ...`. For a local checkout, add
`figma_native_splash: {path: ../figma_native_splash}` under `dev_dependencies` instead. Keep it a
dev dependency, not a regular one. A one-off global install
(`dart pub global activate figma_native_splash`) also works, but `dart run figma_native_splash:<cmd>`
is the reproducible route.

### 2. Write `figma_splash.yaml` in the app root

Splash only (trim `platforms` to the folders that exist; add `ohos` only when `ohos/` exists, and
keep all three only for a three-platform Flutter OHOS app):

```yaml
splash:
  figma:
    phone: "https://www.figma.com/design/<fileKey>/<file-name>?node-id=1-2"
  platforms: [android, ios]
```

Icons only:

```yaml
icon:
  figma: https://www.figma.com/design/<fileKey>/<file-name>?node-id=2-1
  platforms: [android, ios]
```

Both in one file; delete the section that is not needed:

```yaml
schema_version: 1
icon:
  figma: https://www.figma.com/design/<fileKey>/AppIcon?node-id=2-1
  platforms: [android, ios]
splash:
  figma:
    phone: "https://www.figma.com/design/<fileKey>/Launch?node-id=1-2"
    # optional separate tablet board; omit it to reuse the phone board
    # tablet: "https://www.figma.com/design/<fileKey>/Launch?node-id=1-3"
  platforms: [android, ios]
```

Roles are matched by name, case-sensitive, anywhere inside the board, and must match exactly one
visible node per role:

```text
splash board:  splash/background  splash/foreground  splash/branding
icon board:    icon/background    icon/foreground    icon/monochrome
```

- `splash/background` must cover the whole board; hide reference status bars; keep text and
  decorations inside the foreground/branding containers.
- Phone and tablet foreground/branding must share the same aspect ratio (iOS checks it).
- Icons: square board 256–4096 px (1024 recommended), no transparent areas unless
  `background_color` is set; adaptive icons need aligned `icon/background` + `icon/foreground`.
- Draw at logical sizes (e.g. 375×812): export happens at 3x, independent of local fonts.

If the user cannot rename legacy layers, map node IDs instead of renaming:

```yaml
splash:
  figma:
    phone:
      url: "https://www.figma.com/design/<fileKey>/<file-name>?node-id=1-2"
      nodes:
        background: "10:1"
        foreground: "10:2"
        branding: "10:3"
  platforms: [android, ios]
```

- Node IDs accept `1:2` or `1-2`. `nodes` entries are optional; once given, that role no longer falls
  back to its name.
- Off-board artwork (e.g. a brand lockup maintained outside the board) uses `{ id, x, y }`: `x`/`y`
  are the artwork's top-left corner in board coordinates (logical px), both present or both omitted.
  Splash roles only; icon `nodes` accepts plain ID strings.

### 3. `sync` — fetch the design (network + token)

```bash
export FIGMA_ACCESS_TOKEN="..."   # supplied by the user; do not echo it
dart run figma_native_splash:sync
```

Flags: `--project=<app-root>` (default cwd), `--config=<path relative to app root>` (default
`figma_splash.yaml`), `--dry-run` (still needs network and a token). FVM: `fvm dart run ...`.

`sync` writes only `.figma_splash/snapshot/` and `.figma_splash/previews/`; native projects stay
untouched. Exit code `0` means success, `2` a config/network/file error.

When `sync` fails, diagnose before retrying:

| Error | Action |
|---|---|
| HTTP 401/403 | Token missing, expired, lacks `file_content:read`, or the account cannot open the file. Ask the user for a valid token; do not retry blindly. |
| HTTP 429 | Rate limited; wait for the `Retry-After` hint. |
| Matched 0 or several layers | Wrong, hidden or duplicate `splash/<role>` layers or a wrong `node-id`. Ask the user to rename layers to the exact names, or map node IDs with `nodes`. |
| Background bounds mismatch | `splash/background` must be a container covering the whole board. |
| Role is not inside the board | The node is off-board: use `{ id, x, y }` in `nodes.<role>` or point at an on-board node. |
| iOS aspect ratio differs | Rebuild phone/tablet foreground and branding at the same aspect ratio, then sync again. |

To auto-map node IDs, list the board's layers with the read-only Figma API (the token is only sent to
`api.figma.com`); `fileKey` and `nodeId` come from the board URL (`node-id=1-2` → `1:2`):

```bash
FILE_KEY=<fileKey>; NODE_ID=1:2
curl -sS -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/$FILE_KEY/nodes?ids=$NODE_ID&depth=4" \
| python3 -c 'import json,sys
def walk(n,d=0):
    print("  "*d + f"{n.get(\"id\",\"\")}\t{n.get(\"name\",\"\")}\t[{n.get(\"type\",\"\")}]")
    for c in n.get("children") or []:
        walk(c,d+1)
for n in json.load(sys.stdin).get("nodes",{}).values():
    walk(n["document"])'
```

Increase `depth` when the listing is truncated. The response is read-only JSON; confirm the roles
with the user before writing node IDs into `nodes`.

### 4. `preview`, then `create` and `check` (offline)

```bash
dart run figma_native_splash:preview                # optional composition previews
dart run figma_native_splash:create --dry-run       # show planned writes/deletes first
dart run figma_native_splash:create                 # write resources + native wiring
dart run figma_native_splash:check                  # verify; writes nothing
```

- Show the `--dry-run` summary to the user before a non-trivial `create`.
- `create` writes resources, registers the iOS storyboard in Xcode Resources and updates the needed
  `Info.plist`/`module.json5` fields; it does not build, sign or install the app.
- Restrict the scope with `--platform=android|ios|ohos` (must already be enabled in the YAML).
- Conflicts (same-name different content, manually edited generated files) are errors: stop and let
  the user decide; never hand-edit or force-remove generated files.
- `check` exits `0` when the splash wiring is consistent; a missing snapshot, an unwired
  storyboard/`Info.plist`, missing project files or conflicts exit non-zero (run `create` when it
  says so). Ordinary pending asset updates may still exit `0` for splash.
- Previews are schematic (no real system bars or launch animation). Verify on a device/emulator when
  a toolchain is available (`flutter run`, `flutter build apk --debug`,
  `flutter build ios --simulator`).

### 5. Desktop icons (optional)

Add an `icon:` section (see above), then run:

```bash
dart run figma_native_splash:icon sync
dart run figma_native_splash:icon create --dry-run
dart run figma_native_splash:icon create
dart run figma_native_splash:icon check
dart run figma_native_splash:icon preview
```

Icon `check` is strict: any pending asset, manifest or integration change exits `2` and asks for
`icon create`; a clean state exits `0`. Other rules:

- Plain icons use the whole-board export; adaptive icons composite `icon/background` +
  `icon/foreground` (both aligned with the board, foreground keeps transparent padding, keep art
  inside the central 66 dp of 108 dp).
- `icon/monochrome` needs a transparent background and an opaque outline; fully transparent or
  fully opaque layers are rejected. RGB is normalised to white and alpha is preserved.
- iOS/HarmonyOS receive opaque full-colour icons without pre-baked corners. iOS dark/tinted icons,
  Liquid Glass layers and HarmonyOS layered icons are unsupported.
- `icon.background_color` is required when full-colour or adaptive artwork has transparent pixels.
- Never remove `flutter_launcher_icons` or other icon tooling automatically; verify the real icons
  first.

## HarmonyOS (ohos) specifics

HarmonyOS support targets Flutter OHOS projects: `ohos/` must already exist and the app must build on
a Flutter OHOS engine that exposes `FlutterPage`. The tool never creates `ohos/`; if the folder is
missing, tell the user the OHOS platform project is required first.

Enable it through `platforms: [android, ios, ohos]` (splash and icon sections are independent), or
`--platform=ohos` for a single create/check run.

Splash defaults (no extra configuration needed):

- Writes the Ability start-window assets under `ohos/entry/src/main/resources/base/media/` and sets
  `startWindowIcon` / `startWindowBackground` in `ohos/entry/src/main/module.json5`.
- This only updates the native system start window; it adds no promo layer by itself.

Optional second-stage promo view:

```yaml
splash:
  figma:
    phone: "https://www.figma.com/design/<fileKey>/<file-name>?node-id=1-2"
  platforms: [ohos]
  ohos:
    app_splash: true
```

- `app_splash: true` generates the ArkUI layered view and wires it into the `FlutterPage` as
  `splashScreenView: FigmaSplash`; `false` removes only the tool's own wiring.
- The promo view has no fixed display duration, and disabling it does not guarantee the system
  window stays up until Dart's first frame. Custom builders and app-side handling are the user's
  responsibility.
- If the existing `splashScreenView` wiring was edited or is a complex expression, generation throws
  an explicit error instead of guessing; let the user resolve the custom code first.
- No OHOS layered icon support: icons are flat, full-colour 1024 px PNGs.

Paths (defaults; override under `project` when the OHOS project uses non-standard folders):

| Section | Key | Default |
|---|---|---|
| splash | `project.ohos_main` | `ohos/entry/src/main` |
| splash | `project.ohos_page` | `ohos/entry/src/main/ets/pages/Index.ets` |
| splash | `project.ohos_ability` | `EntryAbility` |
| icon | `project.ohos_main` | `ohos/entry/src/main` |
| icon | `project.ohos_app_scope` | `ohos/AppScope` |
| icon | `project.ohos_ability` | `EntryAbility` |

Icons write 1024 px PNGs to `ohos/AppScope` and the selected module, update `app.json5`'s `icon` and
the chosen Ability's `icon`; package name, version, permissions and signing are untouched.

Verification: build with the project's OHOS Flutter toolchain (`flutter build hap`, depending on the
distribution) or in DevEco Studio, and check on an OHOS emulator/device. `check` only validates
generated files and wiring; report OHOS as unverified when no OHOS build or device run was possible.

### 6. Snapshots, git and CI

```text
.figma_splash/
├── snapshot/  icon_snapshot/     commit (versioned design + assets)
├── generated_android.json        commit (generation manifests)
├── generated_ios.json            commit
├── generated_ohos.json           commit
├── previews/  icon_previews/     ignore in git
```

- Commit `figma_splash.yaml`, the snapshots, the `generated_*.json` manifests and the generated
  native resources, so builds and CI stay offline.
- Ignore `.figma_splash/previews/` and `.figma_splash/icon_previews/`.
- Never commit a real `figma_access_token`; keep `""` in shared configs and provide the token through
  `FIGMA_ACCESS_TOKEN` (or a git-ignored local `--config` file).
- CI can run `create` from the committed snapshot without a token; a splash `check` is a useful gate.
- Do not hand-edit snapshot PNGs: hashes are verified and mismatches are rejected.

## Command cheat sheet

| Task | Command |
|---|---|
| Add the dependency | `flutter pub add dev:figma_native_splash` |
| Fetch the design | `dart run figma_native_splash:sync` |
| Compose previews | `dart run figma_native_splash:preview` |
| Plan / write splash | `dart run figma_native_splash:create --dry-run` / `create` |
| Verify splash | `dart run figma_native_splash:check` |
| Icon pipeline | `dart run figma_native_splash:icon sync\|create\|check\|preview` |
| One platform | append `--platform=ios` (create/check only) |
| Another project | append `--project=/path/to/app` |
| Another config | append `--config=config/splash.yaml` |

`sync` and `preview` reject `--platform`. There is no `--all`, `--remove` or recursive folder mode.

## Guardrails

- Never invent Figma node IDs, file keys or layer names; verify them through the Figma URL/API and
  confirm roles with the user.
- Never put tokens into files, logs, commits or generated resources.
- Do not hand-edit generated native files, manifests or snapshots; conflicts are deliberate errors.
- Do not create platform folders or add Flutter `assets:` declarations; generated native assets are
  intentionally not bundled through Flutter assets.
- Do not promise dark-mode, landscape, Liquid Glass or per-flavor icon support.
- Do not claim success for a platform without running `check` (ideally a build) there; report which
  platforms were not verified.

## References

- Full field reference: [references/config-reference.md](references/config-reference.md)
- Package page: [pub.dev/packages/figma_native_splash](https://pub.dev/packages/figma_native_splash)
- README: [English](https://github.com/rx123rx/figma_native_splash/blob/main/README_EN.md) ·
  [中文](https://github.com/rx123rx/figma_native_splash/blob/main/README.md)
- Design template rules `doc/figma-template.md`, validation scope `doc/validation.md` and example
  configs `example/figma_splash.yaml` / `example/figma_icon.yaml` in the repository.
- Install or refresh this skill from the repository: `npx skills add rx123rx/figma_native_splash`
