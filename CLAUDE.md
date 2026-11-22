# Present Tracker

Tanner's Flutter app (iPhone and Android) for tracking gifts per person and occasion. It mirrors
the web version (Claude artifact "Present Tracker"). Tanner is not technical and works from his
phone: explain things in plain words and give exact steps.

- `flutter analyze` and `flutter test` must pass. CI (`.github/workflows/app.yml`) checks every push
  and builds Android (APK download) and an unsigned iPhone build.
- `codemagic.yaml` makes signed iPhone builds for TestFlight, using the same App Store Connect API key
  as Daily Work Log. Bundle ID: `com.presenttracker.app`.
- Illustrations live in `assets/art/` (SVG), exported from the web version.
- Data: one JSON file plus a photos folder in the app's documents folder (`lib/data/store.dart`).
- Photo reading uses the phone's own text recognition (`lib/services/ocr.dart`); `parsePhotoText`
  is plain Dart and tested in `test/ocr_test.dart`.
