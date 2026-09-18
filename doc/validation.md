# Validation scope

The generator is tested as a command-line development tool. A successful generation check is not a substitute for native compilation and device testing in the consuming application.

## Automated checks

- Configuration defaults, required fields, explicit nulls, invalid types, unsupported fields, URL/branch parsing, and Figma node mappings.
- The complete README configuration block matches the standalone YAML example and includes every supported field.
- Mocked Figma API requests pin a design version; asset downloads do not receive the API token. Authentication and rate-limit failures are reported without printing secrets.
- Transformed layers use absolute bounds and preserve exported PNG bytes; background coverage and exported aspect mismatches still fail (mocked Figma responses).
- Snapshot integrity, output conflicts, edited-file protection, project boundary checks, and repeat generation with no changes.
- OHOS app splash opt-in/opt-out, generated-resource cleanup, and preservation of custom host code.
- Shared layout bounds for phone, landscape, tablet and small windows; Android 12 icon safe-circle containment; preview background coverage.

## Native checks performed during development

- iOS Storyboard and Asset Catalog compilation using Xcode command-line tools.
- Android resource compilation and linking with SDK 36 and a minimum API of 24.
- OHOS resource/ArkTS compilation and unsigned HAP packaging.
- OHOS phone emulator: portrait and landscape layered view; an isolated Flutter application reached the first frame with the optional app splash enabled and disabled.

These checks covered the generator before its public naming cleanup; the public package is additionally checked with Dart analysis, automated tests and `dart pub publish --dry-run`.

## Remaining limits

- Real Figma REST export still requires validation with the maintainer's own file and access token; the HTTP tests use mocks.
- End-to-end behavior in arbitrary production applications, physical OHOS devices, tablet emulators, continuous folding/split-screen transitions and all OS versions is not guaranteed by the development fixtures.
- Preview PNGs are schematic renderings, not screenshots from system launch windows.

## Reproduce a local fixture

```bash
dart run tool/create_validation_project.dart /tmp/figma-splash-validation
dart run bin/check.dart --project=/tmp/figma-splash-validation
dart run bin/create.dart --project=/tmp/figma-splash-validation --dry-run
dart run bin/preview.dart --project=/tmp/figma-splash-validation
```

The output directory must not exist. This fixture uses generated artwork only, opts into the OHOS layered view to exercise that code path, and does not need a token. Native compilation requires an appropriate host project and installed platform SDKs.
