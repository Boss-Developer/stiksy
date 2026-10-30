# Stiksy -  Text-to-Sticker

Flutter app for making WhatsApp stickers, aimed at a Pakistani audience. Create a sticker from a photo, emoji or text, edit it, and send it straight to WhatsApp or add it to your own pack. No account needed.

Templates, categories, ready-made sticker packs, app texts and feature switches are not built into the app: they are published from the separate **Stiksy Admin** panel (`stiksy_admin`) and downloaded by the app.

## What's in the app

- **Home, Templates, Catalog, My Packs** in one bottom bar. Template categories, premium templates and favorites.
- **Editor:** multiple text, emoji, photo and shape layers; drag, resize, rotate, duplicate, reorder, lock, hide; undo/redo; text styles (Urdu, Arabic and Latin fonts, colour, outline, shadow); backgrounds; autosave and drafts.
- **Export:** transparent 512×512 WebP under 100 KiB, Send to WhatsApp / WhatsApp Business through the official sticker ContentProvider (3–30 stickers per pack), save, copy, share.
- **Sticker catalog:** 40 Pakistani-culture packs downloaded on demand, each file checked against its SHA-256.
- **Monetisation:** free exports carry a small watermark and premium templates are unlocked by a rewarded video. A one-time **Remove ads & watermark** purchase removes both. There is no subscription.

iOS currently only shares the image; native WhatsApp pack installation is Android only.

## How content reaches the app

```
Stiksy Admin ──Publish──► Supabase bucket stiksy_bucket / v1/
                              manifest.json   templates, categories, settings, pack list
                              <folder>/pack.json, NN.webp, tray.png, cover.webp
                              templates/<slug>.webp

App ──► manifest.json (one request) ──► cache on device
```

- **First launch:** the splash screen checks for internet and downloads the manifest, template art and pack covers before opening the app. Offline or failed: the user can retry or continue with the built-in templates.
- **Later launches:** the app opens from cache and refreshes the manifest in the background. It also refreshes when the catalog is opened or pulled to refresh, at most once every 30 seconds. New content shows up the next time the app checks; nothing is pushed.
- **Changes are detected** by release number (manifest), per-pack version (catalog) and SHA-256 (art and sticker files); only what changed is downloaded.
- **Offline:** cached content, built-in templates, your designs and installed packs all keep working. Every request has a 15 s timeout.
- **Remote settings** control the feature switches (ads, rewarded video, purchase, catalog), minimum app version (forced-update dialog), maintenance message, premium unlock hours, draft limit, app texts, upgrade screen text, text-style presets and editor emoji sets.

The app uses an anonymous Supabase session and can only read the published `v1/` folder.

## Run

The Supabase anon key is passed at build time and is not stored in the repo (`env/` is git-ignored):

```sh
flutter pub get
.\run.ps1                       # prompts for the anon key, then flutter run
.\run.ps1 -d <deviceId>         # extra arguments go to flutter run
# or directly:
flutter run --dart-define=SUPABASE_ANON_KEY=<key>
```

Optional build-time defines: `SUPABASE_URL`, `IAP_PRODUCT_ID` (default `stiksy_remove_ads`, can also be set from the admin panel), `ADMOB_NATIVE_ID`, `ADMOB_REWARDED_ID`. Without them debug builds use Google's test ad IDs, and release builds show no ads at all (and give rewarded unlocks for free) so users never see "Test Ad".

## AdMob setup

Create one AdMob app per platform, each with two ad units:

| AdMob item | Format | Used for | Passed as |
|---|---|---|---|
| App | — | SDK initialisation | Android: `-PadmobAppId=ca-app-pub-…~…`; iOS: `ADMOB_APP_ID` in `ios/Flutter/AdMob.xcconfig` |
| Ad unit | Native advanced | Small ad under the template grid | `--dart-define=ADMOB_NATIVE_ID=ca-app-pub-…/…` |
| Ad unit | Rewarded | Premium template unlock and watermark removal | `--dart-define=ADMOB_REWARDED_ID=ca-app-pub-…/…` |

The Android release IDs (app ID in `android/app/build.gradle.kts`, ad units in `lib/app/services/ad_service.dart`) are built in; debug and profile builds always use Google's test IDs.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
```

## Release (Android)

- Package: `com.sfdevelopers.stiksy`.
- Create `android/key.properties` (git-ignored) with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Without it the release build falls back to the debug key.
- Pass the real AdMob app ID with `-PadmobAppId=ca-app-pub-...~...` (or put `admobAppId=...` in `android/gradle.properties`) and the real ad unit IDs with the defines above. See [AdMob setup](#admob-setup).
- Create the in-app product in Play Console and use its ID as `IAP_PRODUCT_ID` or in the admin panel's upgrade settings. Prices are set in Play, never in the app.

```sh
flutter build appbundle --dart-define=SUPABASE_ANON_KEY=<key> --dart-define=ADMOB_NATIVE_ID=... --dart-define=ADMOB_REWARDED_ID=... -PadmobAppId=...
```

## Assets

- `assets/stickers/`: five small transparent WebP illustrations used as fallbacks and in the splash and onboarding.
- `assets/fonts/`: Noto Nastaliq Urdu, Noto Naskh Arabic, Poppins and Montserrat for offline text, with their SIL OFL licenses.
- `assets/icon/`: source layers for the launcher icon (not bundled in the app). Regenerate the icons with `dart run flutter_launcher_icons`.

Jameel Noori is not bundled because no redistribution license was supplied.

## Design

Corner radii come from one scale in `lib/app/config/app_radius.dart` (6 / 9 / 12 / 16), the same scale the admin panel uses.
