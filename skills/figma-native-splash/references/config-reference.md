# figma_native_splash configuration reference

Compact field reference for agents. The authoritative documentation is the repository
[README_EN.md](https://github.com/rx123rx/figma_native_splash/blob/main/README_EN.md) (and its
[Chinese version](https://github.com/rx123rx/figma_native_splash/blob/main/README.md)); prefer the
README when this file and the README disagree.

The default config file is `figma_splash.yaml` in the app root. Override it with
`--config=<path>`, resolved relative to `--project` (default: the current directory). The root
accepts only `figma_access_token`, `schema_version`, `icon` and `splash`; each command validates
unknown fields, wrong types and explicit `null` inside its own scope.

## Root

| Field | Type | Required | Default / notes |
|---|---|---|---|
| `figma_access_token` | string | no | `""`. A non-empty `FIGMA_ACCESS_TOKEN` environment variable wins. Needed only by `sync` / `icon sync`. Never commit a real token. `null`, numbers and booleans are rejected. |
| `schema_version` | integer | no | `1`; only the integer `1` is accepted. |
| `splash` | map | yes for the splash commands | Icon-only projects may omit the whole section. |
| `icon` | map | yes for the icon commands | Splash-only projects may omit the whole section. |

## splash section

| Field | Type | Required | Default / notes |
|---|---|---|---|
| `splash.figma` | map | yes | Figma is the only source; there is no local artwork input. |
| `splash.figma.phone` | URL string or map | yes | Frame/Component/Instance board, must include `node-id`. |
| `splash.figma.phone.url` | string | yes in object form | `https://figma.com` or `https://www.figma.com` design/file link with `node-id`. |
| `splash.figma.phone.nodes` | map | no | Roles `background`, `foreground`, `branding`; omitted or `{}` resolves by `splash/<role>` name. |
| `splash.figma.phone.nodes.<role>` | node ID string or `{id, x, y}` map | no | Node ID `1:2` or `1-2`. `{id, x, y}` marks off-board artwork: x/y are its top-left in board coordinates, both required. |
| `splash.figma.tablet` | URL string or map | no | Omitted: reuse the phone artwork. Same shape as `phone`; nodes must belong to the tablet board. |
| `splash.platforms` | non-empty list | no | `[android, ios, ohos]`; duplicates merged. Trim it to the platform folders that exist. |
| `splash.resource_prefix` | string | no | `figma_splash`. Lowercase start, then lowercase letters/digits/underscores. Must differ from the icon prefix; renaming after generation is rejected. |
| `splash.background_color` | string | no | `"#FFFFFF"`. Quoted `#RRGGBB` only: no `#RGB`, alpha or gradients. |
| `splash.ohos.app_splash` | boolean | no | `false`; `true` additionally wires `FlutterPage.splashScreenView`. |
| `splash.project.android_res` | relative path | no | `android/app/src/main/res` |
| `splash.project.ios_runner` | relative path | no | `ios/Runner` |
| `splash.project.ohos_main` | relative path | no | `ohos/entry/src/main` |
| `splash.project.ohos_page` | relative path | no | `ohos/entry/src/main/ets/pages/Index.ets` |
| `splash.project.ohos_ability` | string | no | `EntryAbility` |

## icon section

| Field | Type | Required | Default / notes |
|---|---|---|---|
| `icon.figma` | URL string or map | yes | Square board, 256–4096 logical px (1024 recommended). |
| `icon.figma.url` | string | yes in object form | Design link with `node-id`. |
| `icon.figma.nodes` | map | no | Roles `background`, `foreground`, `monochrome`; plain node ID strings only, no `x`/`y`. |
| `icon.platforms` | non-empty list | no | `[android, ios, ohos]`, independent of `splash.platforms`. |
| `icon.resource_prefix` | string | no | `figma_icon`; also the iOS `.appiconset` name and the `AppIcon` build setting. |
| `icon.background_color` | string | no | No default; required when full-colour or adaptive artwork has transparent pixels. Never inherited from splash. |
| `icon.android.adaptive` | boolean | no | `true`; requires aligned `icon/background` + `icon/foreground`. |
| `icon.android.monochrome` | boolean | no | `false`; requires `adaptive: true` and a transparent `icon/monochrome` outline. |
| `icon.project.android_res` | relative path | no | `android/app/src/main/res` |
| `icon.project.android_manifest` | relative path | no | `android/app/src/main/AndroidManifest.xml` |
| `icon.project.ios_runner` | relative path | no | `ios/Runner` |
| `icon.project.ohos_main` | relative path | no | `ohos/entry/src/main` |
| `icon.project.ohos_app_scope` | relative path | no | `ohos/AppScope` |
| `icon.project.ohos_ability` | string | no | `EntryAbility` |

## HarmonyOS (ohos)

- Requires an existing `ohos/` project built on a Flutter OHOS engine exposing `FlutterPage`; the
  tool never creates the platform folder. Add `ohos` to `platforms` only when it exists.
- Default splash wiring updates the native start window (`startWindowIcon` / `startWindowBackground`
  in `ohos/entry/src/main/module.json5`) and writes assets under
  `ohos/entry/src/main/resources/base/media/`.
- `splash.ohos.app_splash: true` additionally generates the ArkUI layered promo view wired as
  `splashScreenView: FigmaSplash`; it has no fixed display duration and only removes tool-managed
  wiring when turned off.
- Paths: `splash.project.ohos_main` (`ohos/entry/src/main`), `splash.project.ohos_page`
  (`ohos/entry/src/main/ets/pages/Index.ets`), `splash.project.ohos_ability` (`EntryAbility`);
  icons use `icon.project.ohos_main`, `icon.project.ohos_app_scope` (`ohos/AppScope`) and
  `icon.project.ohos_ability`.
- Icons are flat full-colour 1024 px PNGs written to `ohos/AppScope` and the selected module,
  updating `app.json5`'s icon and the Ability icon; layered OHOS icons are unsupported.

## Rules that bite

- Optional field is not optional design layer: all three splash roles and the required icon layers
  must exist in the board even when only one platform is generated.
- Roles are case-sensitive, must match exactly one visible node, and hidden nodes are not candidates.
- `nodes: {}`, `ohos: {}` and `project: {}` are valid; `platforms: []` is not. To use a default,
  delete the field instead of writing `null`, `""` or `"false"`.
- `project.*` paths are relative to `--project`, must stay inside it: no absolute paths, no `../`
  escaping and no symlinked outputs.
- On-board role rectangles use the transformed absolute bounds; `splash/background` must cover the
  whole board. Rotated/mirrored layers are supported and the exported PNG ratio must match the bounds.
- Phone and tablet foreground/branding must keep the same aspect ratio (iOS enforces it).
- The same Figma file pins one version per sync; phone and tablet may come from different files.
  Re-run `sync` after changing links, node mappings, a tablet board or the set of downloaded Android
  icon layers; colour/platform-only changes just need `create`.
- The tool only reads Figma. The token is sent to `api.figma.com` but never to image download URLs,
  and never written into generated resources or snapshots.
