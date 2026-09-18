## 0.1.0

- Fix missing iOS Xcode Resources registration; create now patches project.pbxproj idempotently and check reports incomplete storyboard integration.

- Generate native Android, iOS and HarmonyOS splash resources from Figma design links.
- Accept rotated and mirrored layers using transformed bounds and exported PNGs, retaining coverage and aspect checks.
- Support named design layers and explicit node mappings for phone and tablet frames.
- Save versioned, integrity-checked design snapshots for offline generation.
- Provide sync, check, create, preview, per-platform generation and dry-run commands.
- Make the HarmonyOS app splash opt-in and clean up generated layers when disabled.
- Protect manually edited outputs and preserve unrelated host application configuration.
- Document every configuration field, its defaults and omission behavior.
