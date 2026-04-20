# Replace `com.example` with `com.signaracollar.app`

## Goal

Stop using the placeholder **`com.example.*`** identifiers. Use a single production-style ID everywhere:

- **iOS / macOS Bundle ID:** `com.signaracollar.app`
- **Android `applicationId` / `namespace`:** `com.signaracollar.app`

You confirmed this choice in the planning flow.

## Apple Developer & App Store Connect

1. In **Certificates, Identifiers & Profiles**, create (or edit) an **App ID** with **`com.signaracollar.app`**.
2. In **App Store Connect → New App**, choose this **Bundle ID** from the dropdown (after step 1).
3. **SKU:** any unique string (e.g. `signaracollar-app-ios-001`).

## Firebase (required for a working build)

Firebase config files are tied to **bundle ID / package name**. After you register the new iOS app and Android app in the Firebase project:

1. Download fresh **`GoogleService-Info.plist`** (iOS/macOS) and **`google-services.json`** (Android).
2. Replace the files under **`ios/Runner/`**, **`macos/Runner/`**, and **`android/app/`**.
3. Regenerate **`lib/firebase_options.dart`** with FlutterFire CLI, e.g. `flutterfire configure`, so **`iosBundleId`**, **`appId`**, and keys match the new apps.

Until Firebase is updated, only changing Xcode/Gradle IDs will cause **Firebase init / Google Sign-In** mismatches.

## Code & project files to change (execution checklist)

### iOS

- [ **`ios/Runner.xcodeproj/project.pbxproj`** ](ios/Runner.xcodeproj/project.pbxproj): `PRODUCT_BUNDLE_IDENTIFIER` for Runner → `com.signaracollar.app`; RunnerTests → `com.signaracollar.app.RunnerTests` (or your team’s test convention).

### macOS

- [ **`macos/Runner/Configs/AppInfo.xcconfig`** ](macos/Runner/Configs/AppInfo.xcconfig): `PRODUCT_BUNDLE_IDENTIFIER` and update `PRODUCT_COPYRIGHT` if it still says `com.example`.
- [ **`macos/Runner.xcodeproj/project.pbxproj`** ](macos/Runner.xcodeproj/project.pbxproj): bundle IDs for Runner and RunnerTests.

### Android

- [ **`android/app/build.gradle.kts`** ](android/app/build.gradle.kts): `namespace` and `applicationId` → `com.signaracollar.app`.
- Move **`MainActivity.kt`** from `android/app/src/main/kotlin/com/example/slgnara_collar/` to `android/app/src/main/kotlin/com/signaracollar/app/`.
- Update **`package`** in `MainActivity.kt` to `com.signaracollar.app`.
- Delete the old empty package directories if unused.

### Dart (manual until FlutterFire runs)

- [ **`lib/data/remote/auth_service.dart`** ](lib/data/remote/auth_service.dart): `androidPackageName` and `iOSBundleId` in `ActionCodeSettings` → `com.signaracollar.app`.
- [ **`lib/firebase_options.dart`** ](lib/firebase_options.dart): regenerate via **`flutterfire configure`** (preferred) so `iosBundleId` and Android `appId` match new Firebase apps.

### Config files from Firebase (after console setup)

- [ **`ios/Runner/GoogleService-Info.plist`** ](ios/Runner/GoogleService-Info.plist)
- [ **`macos/Runner/GoogleService-Info.plist`** ](macos/Runner/GoogleService-Info.plist)
- [ **`android/app/google-services.json`** ](android/app/google-services.json)

### Other (optional consistency)

- [ **`linux/CMakeLists.txt`** ](linux/CMakeLists.txt): `APPLICATION_ID` → `com.signaracollar.app` if you ship Linux.
- [ **`windows/runner/Runner.rc`** ](windows/runner/Runner.rc): replace `com.example` in metadata if you care about Windows branding.

## Notes

- **Google Sign-In** and **password reset** deep links depend on the bundle ID / package matching Firebase and **`auth_service.dart`**.
- Do **not** partially change only Xcode without Firebase: builds may run but Firebase will fail at runtime.

## Status

This document is the **plan**. Implementation starts only when you explicitly ask to execute (e.g. “implement the bundle ID change”).
