# Stiksy Pakistani culture catalog — v1

40 predefined packs, 10 stickers per pack, 400 final static stickers. Each title is a separate numbered folder. Captions are Roman Urdu (`ur-Latn-PK`). Artwork was created with the built-in ImageGen tool; each pack combines its original illustration with 10 distinct captions and native-rendered layouts.

## Upload layout

Upload this **entire v1 directory**, preserving the folder names:

```
v1/
  catalog.json
  inventory.json
  inventory.csv
  01-chai-ho-jaye/
    pack.json
    tray.png
    cover.webp
    01.webp ... 10.webp
  ...
  40-dil-dil-pakistan/
```

`catalog.json` lists 40 packs, categories, counts, relative manifest/cover/tray paths and manifest checksums. `pack.json` lists that pack's 10 stickers, captions, accessibility text, emoji tags, dimensions, byte sizes and SHA-256 checksums. `inventory.json` and `inventory.csv` contain all 400 stickers for importing into a database.

All sticker files are transparent **512 × 512 WebP**, below **100 KiB** each. Tray icons are transparent **96 × 96 PNG**, below **50 KiB**. Covers are **256 × 256 WebP**. These are static packs, with 10 stickers each; no watermark is baked into them.

## Serving and app integration

Serve JSON as `application/json`, WebP as `image/webp`, and PNG as `image/png`. After uploading, the catalog entry point is your actual hosting base URL followed by `/v1/catalog.json`. Resolve the relative paths against the v1 directory. No hosting domain or credentials are embedded in these files.

Fetch the small catalog and pack cover first. Fetch a pack's manifest and its 10 stickers only when the user selects/downloads that pack, then cache locally. Verify each downloaded file's byte size and SHA-256 against the manifest. For Android WhatsApp installation, pass the downloaded files through Stiksy's native pack store/content provider; a CDN URL by itself does not register a WhatsApp sticker pack.

These assets are intentionally outside Flutter's `assets/` directory and `pubspec.yaml`: they do not increase APK size. This delivery prepares server content; it does not upload files or connect the current app to an unconfigured server.

Keep pack IDs and folder names stable. Publish edited artwork/captions as a new catalog version, such as v2, and increment pack versions for cache invalidation.

## Preview and sources

The project includes an overview, one contact sheet for every pack, and a browser review page under `output/sticker-catalog-preview/`. Editorial captions, exact generation prompts, local source artwork, and validation results live in `content/sticker-catalog-source/`; those source files are excluded from the upload ZIP.

Rebuild instructions are in `content/sticker-catalog-source/README.md`.
