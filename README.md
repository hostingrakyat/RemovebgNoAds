# Removebg No Ads

**Background remover. Free. No Ads. Offline. HD output. Forever.**

Day 5 of Ir. Riovan Styx Roring's *365 Days App Challenge* — one free, no-ads
Flutter Android app per day.

## What it does
- Pick an image from the gallery **or** capture from the camera
- Remove the background fully **on-device** (Google ML Kit Subject Segmentation — no API calls)
- Output a **transparent PNG at the original resolution** (HD — the source is never downscaled)
- Swap the background: **transparent / solid color / another image**
- **Manual touch-up brush** (erase / restore)
- **Before/after compare slider**, zoom & pan
- **Save to gallery** and **share**
- Recent results grid on the home screen

## How HD output works
ML Kit returns a foreground **confidence mask**. The app upscales that mask
(bilinearly) to the original image dimensions and applies it as the alpha
channel of the original full-resolution pixels — the photo itself is never
resized down. Heavy pixel work runs in a background isolate.

## Offline note (read this)
ML Kit **Subject** Segmentation is delivered through Google Play Services and
has **no in-APK bundled variant**. The model is downloaded **once** on first use
(a few MB, internet needed that one time), then everything runs fully offline
forever. On Play-Store installs the model is prefetched at install time via the
`com.google.mlkit.vision.DEPENDENCIES` manifest hint. For truly zero-download
bundling you would need ML Kit *Selfie* Segmentation (people only) or a bundled
tflite U2Net/MODNet model.

## Tech stack
- Flutter 3.24.5, AGP 8.6.1, Gradle 8.7, Kotlin 1.9.24
- compileSdk 35, targetSdk 35, **minSdk 24** (required by ML Kit Subject Segmentation)
- Material 3, `google()` + `mavenCentral()` only

## Key packages
`google_mlkit_subject_segmentation`, `image`, `image_picker`, `share_plus`,
`permission_handler`, `path_provider`, `path`, `url_launcher`,
`shared_preferences`, `flutter_colorpicker`.

Saving to the gallery is done natively via a small MediaStore MethodChannel in
`MainActivity.kt` (no third-party plugin) to keep the Gradle stack clean on
Flutter 3.24.5.

## Building
APK + AAB are built by GitHub Actions (`.github/workflows/build.yml`) on every
push to the working branch and on manual dispatch. Both files are uploaded as
workflow artifacts and attached to a GitHub Release.

### Signing
- Run **Generate Keystore** (`.github/workflows/generate-keystore.yml`) once and
  copy the four printed values into repository secrets:
  `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
- With those secrets set, the release is **signed**.
- With **no** keystore present, the release builds **unsigned** (it does *not*
  fall back to debug signing) so you can sign it yourself later.

## Credits
Created by: **Ir. Riovan Styx Roring**
- TikTok: https://www.tiktok.com/@ir.riovansroring
- Instagram: https://www.instagram.com/ir.riovansroring/
- YouTube: https://youtube.com/@ir.riovanroring
