# Sticker catalog sources

- `plan.json`: 40 editorial pack definitions, 10 Roman Urdu captions per pack.
- `generated-art.json`: exact prompts used with the built-in ImageGen tool, plus local illustration paths.
- `prepared/01.png` through `prepared/40.png`: project-local transparent artwork used by the native renderer. High-resolution generation originals are retained in Codex's generated-images directory.
- `validation.json`: final file counts, sizes, transparency/dimension checks and checksum audit.

40 original illustrations are reused across 400 caption/layout compositions; these are 400 distinct final sticker files, not 400 separately generated illustration poses. Each pack has ten distinct captions and ten layouts.

## Rebuild

For lasting editorial changes, edit `ROWS` in `tools/sticker_catalog_plan.py` before regenerating `plan.json`. If you edit `plan.json` directly, skip the first command below. Existing verified exports are reused by source-image checksum; changed renders are recompressed. Compression runs across six workers.

Run from the project root with Flutter and Python/Pillow available:

```
python3 tools/sticker_catalog_plan.py
python3 tools/package_sticker_catalog.py --prepare-art
flutter test --no-pub tools/render_sticker_catalog_test.dart
python3 tools/package_sticker_catalog.py --package --zip
```

For a quick partial review, set `STIKSY_RENDER_PACKS=13` on the Flutter render command, then use `--package --partial`. A final upload requires all 40 packs.

The renderer uses the bundled SIL OFL Poppins Bold font via Flutter's native text engine. Text is typeset separately from image generation for exact spelling and consistent readability. Source art is prepared at 512px; final WebP defaults to quality 68, with alpha preserved and lower quality only if needed to stay below 100 KiB. Covers use quality 60. Large original PNGs and intermediate renders under `build/` are excluded from server exports and the APK.
