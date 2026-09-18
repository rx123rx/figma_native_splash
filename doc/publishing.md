# Publishing

This package is prepared for pub.dev, but creating the package files or running a dry run does not publish it.

1. Confirm the package name is still available and that the release version is correct.
2. Confirm the MIT license and copyright attribution with the rights holder. The initial attribution is `figma_native_splash contributors`.
3. Set `repository` in `pubspec.yaml` to the real public source repository once available. Optionally add real `homepage`, `issue_tracker` and `documentation` URLs. Do not use placeholder URLs.
4. Run the following checks from the package root:

   ```bash
   ./tool/publish.sh
   ```

   The script runs dependency resolution, format checks, static analysis, tests and `dart pub publish --dry-run`, stopping on the first failure. It resolves the package root from its own location, so it can also be invoked from another directory. `--dry-run` explicitly selects the default mode; add `--fvm` to use `fvm dart`. Run `./tool/publish.sh --help` for all options.

5. Inspect the upload file list. `.pubignore` excludes local caches, credentials, logs and the dependency lockfile. Examples and tests must not contain private Figma file IDs, application artwork, machine paths or organization-specific namespaces.
6. Validate the real Figma export with an authorized token and confirm the generated screens in native applications before claiming full production validation.
7. When ready to release, run `./tool/publish.sh --publish` (or `./tool/publish.sh --publish --fvm`). This repeats all checks, then runs `dart pub publish` with the standard upload confirmation and pub.dev authentication. The script does not change the version, create a commit or tag, or bypass publishing warnings. Update `pubspec.yaml` and `CHANGELOG.md` before each release.

Changes to the configuration example should be made in README and mirrored into `example/figma_splash.yaml`; a test enforces equality. The default OHOS app splash is disabled.
