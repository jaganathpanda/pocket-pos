# Android App Variants

The project shares one codebase and produces two app variants:

- POS uses `lib/main_pos.dart`, `posRouterProvider`, and only shared POS routes.
- Rice Mill uses `lib/main_rice_mill.dart`, `riceMillRouterProvider`, and the shared POS routes plus `lib/features/rice_mill/`.

Build debug APKs with:

```sh
flutter build apk --debug --flavor pos -t lib/main_pos.dart
flutter build apk --debug --flavor riceMill -t lib/main_rice_mill.dart
```

Use `--release` instead of `--debug` for release APKs. Android gives the Rice Mill app the separate application ID `com.mypocketpos.app.ricemill` and launcher name `Pocket Rice Mill`; POS retains `com.mypocketpos.app` and `Pocket POS`.

## Firebase Setup Required For Rice Mill

The checked-in `android/app/google-services.json` currently registers only `com.mypocketpos.app`. Register `com.mypocketpos.app.ricemill` as another Android app in the same Firebase project, then download an updated `google-services.json` containing both Android clients. The Rice Mill app also needs FlutterFire options generated for its Firebase Android app ID. Until those Firebase registrations/configuration are supplied, the POS flavor can use the current config, but the Rice Mill flavor is not ready for a functional Firebase build.

For other platforms, use the Rice Mill entry point with the matching platform-specific bundle/application ID and Firebase options before distributing that app variant.
