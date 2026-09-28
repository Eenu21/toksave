# TokSave

TokSave is an Android-first Flutter app for saving TikTok videos that you are
authorized to download. It keeps a local download history and remembers the
creators associated with successful downloads.

## Download options

- **Single video:** paste one TikTok video link, review the formats returned by
  the metadata provider, then download that video.
- **Bulk:** open the creator card to select multiple videos. If the provider
  does not return a creator feed, paste several video links into the profile
  screen to build a batch list. Bulk downloads run one file at a time and show
  progress.

The formats (Standard, HD, and audio when offered) and approximate sizes come
from the provider response. TokSave does not claim to transcode videos into
resolutions the provider did not supply, and it hides size estimates when the
provider omits them.

Downloads are stored in Android's app-specific storage and copied to the
device's shared media library under `Movies/TokSave` (video) or `Music/TokSave`
(audio). Creator history and download records are stored locally in SQLite.
Nothing is uploaded to a TokSave account or server.

## Provider availability

TokSave currently uses the public TikWM service for video metadata and media
links. This is a replaceable integration, not an official TikTok API. Its
availability and response formats can change. In particular, if it refuses
creator-feed requests, the app keeps the pasted video available and supports
building a batch list by pasting individual public video links. The app does
not bypass provider access controls.

## Requirements

- Flutter 3.41 or later (Dart 3.11 or later)
- Android SDK and an Android device or emulator
- Android 10 or later for saving to the shared media library

## Run locally

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Build a debug APK:

```powershell
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Configuration before release

- Replace the sample app identity and support/privacy/terms links in
  `lib/core/constants/app_constants.dart`.
- Replace Google Mobile Ads test IDs with approved production IDs only after
  setting up the production AdMob app.
- Configure Android release signing; debug signing is for local testing only.
- Review the provider's terms and applicable copyright, privacy, and platform
  requirements before distribution.

## Repository workflow

```powershell
git status
git add .
git commit -m "Describe your change"
git push
```

Keep signing keys, credentials, private API keys, and machine-local files out of
the repository. Build output and Flutter tool state are ignored by `.gitignore`.
