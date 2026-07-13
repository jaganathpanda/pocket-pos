# Installation Guide

## Prerequisites

- Flutter latest stable
- Dart SDK (bundled with Flutter)
- Android SDK for Android deployment
- Visual Studio Build Tools for Windows desktop
- Chrome for Flutter web

## Setup

1. Clone/open workspace.
2. Run `flutter doctor` and fix missing dependencies.
3. Run:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

4. Launch app:

```bash
flutter run -d windows
flutter run -d android
flutter run -d chrome
```

## Build Outputs

```bash
flutter build apk --release
flutter build windows --release
flutter build web --release
```

## Backup/Restore

- DB file export/import service is available in core services.
- Keep backup copy outside app sandbox for safety.
