# Publishing

This package is prepared for pub.dev, but creating the package files or running a dry run does not publish it.

1. Confirm the package name is still available and that the release version is correct.
2. Confirm the MIT license and copyright attribution with the rights holder. The initial attribution is `figma_native_splash contributors`.
3. Set `repository` in `pubspec.yaml` to the real public source repository once available. Optionally add real `homepage`, `issue_tracker` and `documentation` URLs. Do not use placeholder URLs.
4. Run the following checks from the package root:

   ```bash
   dart pub get
   dart format --output=none --set-exit-if-changed lib bin test tool example
   dart analyze
   dart test
   dart pub publish --dry-run
   ```

5. Inspect the upload file list. `.pubignore` excludes local caches, credentials, logs and the dependency lockfile. Examples and tests must not contain private Figma file IDs, application artwork, machine paths or organization-specific namespaces.
6. Validate the real Figma export with an authorized token and confirm the generated screens in native applications before claiming full production validation.
7. When the release is approved, the maintainer can run `dart pub publish` and complete pub.dev authentication. Publishing is a separate manual action; this repository's preparation does not run it.

Changes to the configuration example should be made in README and mirrored into `example/figma_splash.yaml`; a test enforces equality. The default OHOS app splash is disabled.
