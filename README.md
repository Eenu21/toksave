# TokSave

TokSave is an Android-first Flutter app for saving TikTok videos that you are
authorized to download. It keeps a local download history and remembers the
creators associated with successful downloads. Recently checked video details
and frequently visited creator profiles are also remembered locally for quick
access.

## Download options

- **Single video:** paste one TikTok video link, review the formats returned by
  the metadata provider, then download that video. Pasting a video link
  automatically starts the lookup.
- **Bulk:** open the creator card to select multiple videos. If the provider
  does not return a creator feed, paste several video links into the profile
  screen to build a batch list. Bulk downloads run one file at a time and show
  progress.

The formats (Standard, HD, and audio when offered) and approximate sizes come
from the provider response. TokSave does not claim to transcode videos into
resolutions the provider did not supply, and it hides size estimates when the
provider omits them.

Downloaded videos opened from Downloads use a full-screen player with seek,
mute, and volume controls. It shows one timeline by default; the scissors
button exposes draggable start/end handles on that same timeline, then the
repeat button loops the highlighted section or the full video.

Downloads are stored in Android's app-specific storage and copied to the
device's shared media library under `Movies/TokSave` (video) or `Music/TokSave`
(audio). Download records, up to 30 recent video lookups, and creator visit
counts are stored locally in SQLite; recent thumbnails are cached on-device.
Nothing is uploaded to a TokSave account or server.

## Provider availability

TokSave currently uses the public TikWM service for video metadata and media
links. This is a replaceable integration, not an official TikTok API. Its
availability and response formats can change. In particular, if it refuses
creator-feed requests, the app keeps the pasted video available and supports
building a batch list by pasting individual public video links. The app does
not bypass provider access controls. TikTok does not offer a general consumer
API for listing arbitrary creators' videos; its Video List API is limited to
the account holder who authorizes access.

Creator profiles keep working as in-app batch workspaces when the public feed
is blocked: they show matching videos already downloaded or checked on this
device, can recheck those links, and accept pasted video links for batch
selection.

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

- Replace the sample app identity in `lib/core/constants/app_constants.dart`
  before release.
- Replace Google Mobile Ads test IDs with approved production IDs only after
  setting up the production AdMob app.
- Configure Android release signing; debug signing is for local testing only.
- Review the provider's terms and applicable copyright, privacy, and platform
  requirements before distribution.
- Privacy and terms information and third-party package license notices are
  available inside the app's Settings screen. No open-source license has been
  selected for TokSave's own source code; do not remove third-party license
  notices.

## Repository workflow

```powershell
git status
git add .
git commit -m "Describe your change"
git push
```

Keep signing keys, credentials, private API keys, and machine-local files out of
the repository. Build output and Flutter tool state are ignored by `.gitignore`.
