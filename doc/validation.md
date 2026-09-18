# Validation scope

The generator is tested as a command-line development tool. A successful generation check is not a substitute for native compilation and device testing in the consuming application.

## Automated checks

- Configuration defaults, required fields, explicit nulls, invalid types, unsupported fields, URL/branch parsing, and Figma node mappings.
- The complete README configuration block matches the standalone YAML example and includes every supported field.
- Mocked Figma API requests pin a design version; asset downloads do not receive the API token. Authentication and rate-limit failures are reported without printing secrets.
- Transformed layers use absolute bounds and preserve exported PNG bytes; background coverage and exported aspect mismatches still fail (mocked Figma responses).
- Xcode OpenStep parsing and targeted edits; new/existing/localized storyboard references, missing Resources phases, multiple targets, repeat generation, and CLI check/dry-run/create behavior.
- Snapshot integrity, output conflicts, edited-file protection, project boundary checks, and repeat generation with no changes.
- OHOS app splash opt-in/opt-out, generated-resource cleanup, and preservation of custom host code.
- Shared layout bounds for phone, landscape, tablet and small windows; Android 12 icon safe-circle containment; preview background coverage.

## Native checks performed during development

- iOS Storyboard and Asset Catalog compilation using Xcode command-line tools.
- Android resource compilation and linking with SDK 36 and a minimum API of 24.
- OHOS resource/ArkTS compilation and unsigned HAP packaging.
- OHOS phone emulator: portrait and landscape layered view; an isolated Flutter application reached the first frame with the optional app splash enabled and disabled.

The initial native checks covered the generator before its public naming cleanup. The Xcode registration fix was additionally validated in an isolated iOS application: the CLI registered a previously unreferenced storyboard, Xcode built the simulator application successfully, and the resulting App contained both the compiled launch storyboard and Assets.car. Repeated generation reported no changes. This is a packaging check, not a cold-launch visual test of the consuming application. The public package is also checked with Dart analysis, automated tests and `dart pub publish --dry-run`.

## Remaining limits

- Real Figma REST export still requires validation with the maintainer's own file and access token; the HTTP tests use mocks.
- End-to-end behavior in arbitrary production applications, physical OHOS devices, tablet emulators, continuous folding/split-screen transitions and all OS versions is not guaranteed by the development fixtures.
- Preview PNGs are schematic renderings, not screenshots from system launch windows.

## Reproduce a local fixture

```bash
dart run tool/create_validation_project.dart /tmp/figma-splash-validation
dart run bin/create.dart --project=/tmp/figma-splash-validation --dry-run
dart run bin/create.dart --project=/tmp/figma-splash-validation
dart run bin/check.dart --project=/tmp/figma-splash-validation
dart run bin/preview.dart --project=/tmp/figma-splash-validation
```

The output directory must not exist. This fixture uses generated artwork only, opts into the OHOS layered view to exercise that code path, and does not need a token. Native compilation requires an appropriate host project and installed platform SDKs.


## App icon validation

- Icon-only and combined configuration, defaults, invalid inputs, documented YAML consistency, snapshot hashes, opaque compositing, adaptive-layer alignment and monochrome alpha masks are tested.
- Mock Figma tests pin a version and verify that asset download requests do not carry credentials. Real icon export still needs an authorized Figma file/token; it has not been validated against a live icon design.
- Generation tests cover Android application/launcher references, iPhone/iPad AppIcon sizes and all app build configurations, HarmonyOS AppScope and Ability references, comments, unrelated settings, cleanup when adaptive/monochrome are disabled, manual-edit protection, CLI dry-run/check and repeated generation.
- Generated Android ordinary/adaptive/API 33 monochrome resources compiled and linked with Android SDK 36 (minSdk 21 fixture).
- An isolated iOS simulator application built with the generated AppIcon; the packaged Info.plist identifies `figma_icon` for iPhone and iPad and contains the compiled asset catalog.
- An isolated HarmonyOS application compiled and packaged successfully; both AppScope and Ability PNG resources are present in the unsigned HAP.
- These are native build checks using synthetic artwork, not launcher screenshots or live Figma acceptance. Android/iOS/HarmonyOS launcher appearance, themed icons and physical devices still need visual acceptance with the consuming app's real design.

Create an icon-only synthetic fixture:

```bash
dart run tool/create_icon_validation_project.dart /tmp/figma-icon-validation
dart run bin/icon.dart check --project=/tmp/figma-icon-validation
dart run bin/icon.dart preview --project=/tmp/figma-icon-validation
```

The output directory must not exist. The fixture validates generation; native compilation requires a complete platform host and installed SDKs.

## Configuration structure

- Tests cover independent icon/splash defaults and paths, required sections, version/type validation, unknown root fields and prefix collisions. README samples and fixture tools use the same icon/splash structure (schema version 1).
- Moving existing effective settings into the two sections preserves snapshot source hashes. Offline checks and dry runs in the consuming three-platform app reported no pending resource or integration changes. This configuration change does not repeat native compilation or device visual checks.
