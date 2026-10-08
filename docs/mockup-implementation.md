# Mockup implementation coverage

| Screen | Working interactions |
| --- | --- |
| Splash | Generated bubble wordmark with crown, green gradient, four compact illustrations, minimum 3 seconds, onboarding persistence. |
| Home | Trending artwork, categories, search, bottom navigation, create editor shortcut. |
| Category | Category/search/free/premium/favorites filters, premium crowns, preview navigation. |
| Template preview | Checkerboard artwork, favorite heart, horizontal similar templates, use template. |
| Editor | Separate 512px text/artwork/emoji/vector/photo layers, select/drag, resize handle, pinch/rotate, undo/redo, local draft save, export. Selection UI stays outside export boundary. |
| Text Style | Font/Color/Effects/Align tabs; licensed offline fonts, size, color, opacity, outline width, shadow blur, spacing, rotation and alignment. |
| Backgrounds & Elements | Transparent/solid/gradient/four vector patterns/photo backgrounds; categorized emoji, vector shapes and reusable artwork; gallery image import compressed on Android. |
| Layers | Add text/sticker, select, reorder with drag handles, duplicate, delete, lock/unlock and visibility. Drafts preserve individual transforms/styles and migrate the earlier draft schema. |
| Export | Transparent 512px WebP below 100 KiB on Android, gallery save, image/text clipboard, other-app image sharing, rewarded watermark removal. |
| WhatsApp | Share-options modal, WhatsApp/Business target, persistent pack chooser, minimum 3 stickers before native installation; cancellation/rejection feedback. Image sharing and native sticker installation are distinctly labelled. |
| My Sticker Packs | Create, real saved sticker thumbnails, view pack, remove sticker, rename/delete pack, install pack, reopen drafts, explore starter collections. |
| Premium | Crown, benefits, monthly/yearly selection and dismiss. Purchasing remains disabled until real Play/App Store subscription products are configured. Displayed prices are mockup values. |

Google sample ad IDs remain in this development build. Rewarded premium-template unlock lasts 24 hours. No fake purchase or premium entitlement is granted by a UI selection.

The bundled fonts are Noto Nastaliq Urdu, Noto Naskh Arabic, Poppins and Montserrat, plus System Sans. Jameel Noori requires a redistribution license before it can be included. Later roadmap features such as cloud/AI/animated stickers are outside the supplied 12-screen mockup.

Validation: Flutter tests cover the 3-second splash, filters, editor undo/redo, independent-layer duplication/locking/reorder/drag and save/reopen, legacy drafts, narrow layouts, export dimensions/transparency, watermark rendering, and aspect-preserving photo import. All 13 Flutter tests passed, with no analyzer issues. Six Android instrumentation tests passed on a Samsung for encoding, provider security/contracts, pack limits and rename/removal. Actual WhatsApp confirmation/chat sending and ad delivery are not claimed as verified by the automated tests. A temporary WhatsApp preview pack was cleaned up after the device check.

`output/ui-preview/overview.jpg` shows all twelve latest screens at 390×844 logical pixels. Those renders use local test fixture packs and no live ad or purchase traffic. The preview generator and device smoke-test helper were temporary and are excluded from the project test suite.
