# Stiksy

Flutter sticker app based on the supplied green/white mobile mockup. Offline, no account required.

Implemented: illustrated onboarding, searchable categorized template gallery with free/premium filters, favorites, recent templates, preview, editable Urdu/English/Roman Urdu text, outline/shadow/alignment, five font choices, font size/color/opacity, outline and shadow sliders, alignment/spacing/rotation, solid/gradient/pattern/photo backgrounds, emoji/vector/photo elements, multiple independent layers with drag/resize/rotate/duplicate/delete/reorder/visibility/lock, undo/redo, local design saving and reopening, collections, premium screen, 512px PNG rendering and the native image share sheet.

Android now exports transparent 512×512 WebP below 100 KiB, saves to gallery, copies sticker images, and stores local packs with the official WhatsApp ContentProvider contract. Packs need 3–30 stickers before installation; WhatsApp or WhatsApp Business displays its own confirmation. Direct image sharing is separately labelled and does not install a native sticker. iOS currently uses PNG/image sharing.

Free exports include a subtle watermark. Completing a rewarded test ad removes it for that export; premium templates can be unlocked for 24 hours with a rewarded test ad. Gallery native ads and editor banners use Google's official test IDs only. Splash remains visible for at least three seconds.

Premium purchases remain disabled until real store products are configured. Jameel Noori is not bundled because a redistribution license has not been supplied; Noto Nastaliq and Noto Naskh are the licensed Urdu options. Animated stickers, curved text, referrals/cloud features and other later roadmap items remain pending. Prices on the premium screen are mockup values. Ad rewards require network access; editing/rendering and stored packs work offline.

## Run

```sh
flutter pub get
flutter run
```

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
```

## Assets

Four transparent 320px WebP illustrations plus the splash wordmark total 127.7 KiB. Full-resolution generation sources are excluded from Flutter assets. Fonts are bundled for offline use: Noto Nastaliq Urdu, Noto Naskh Arabic, Poppins and Montserrat, with their SIL OFL licenses. Naskh and Montserrat use fixed bold instances to reduce payload. Generation prompt summaries and exact sizes are in `docs/sticker-assets.md`.

Mobile layout review screenshots are in `output/ui-preview/` (test-rendered at 390 × 844). Flutter tests cover splash, editor state, export contracts and watermark rendering. Six Android instrumentation tests passed on a Samsung phone for encoding, pack metadata, limits and provider security. Actual WhatsApp confirmation/chat sending and ad delivery still require a manual device check. The twelve screenshots and overview reflect the latest UI. Preview packs are local test fixtures; WebP encoding in the preview was performed with Pillow at quality 70, while the app uses Android compression. See `docs/mockup-implementation.md` for screen coverage.

## Server-ready Pakistani culture stickers

40 packs × 10 predefined stickers are stored in `content/sticker-catalog/v1/`, separately from bundled app assets. Upload instructions: `content/sticker-catalog/v1/README.md`. Sources and rebuild instructions: `content/sticker-catalog-source/README.md`. Preview: `output/sticker-catalog-preview/index.html`. Upload archive: `output/stiksy-pakistani-culture-v1.zip`.
