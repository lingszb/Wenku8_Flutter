---
name: android-build-ci
description: Use for Flutter or Android environment setup, Gradle/NDK/CMake failures, GitHub Actions changes, APK verification, artifact delivery, signing, or release build problems in this repository.
---

# Android build and CI

Follow [shared agent rules](../../PROJECT_GUIDE.md). Read [CI/CD baseline](../../../docs/CI_CD.md), [source build](../../../docs/SOURCE_BUILD.md), and the **current** [Android workflow](../../../.github/workflows/android-apk.yml) before changing the toolchain.

## Known project baseline

- Android-first Flutter project. The CI workflow currently pins Flutter **3.47.9**, JDK **17**, Android SDK platform **36**, Build Tools **36.0.0**, CMake **3.22.1**.
- `android/settings.gradle.kts` configures AGP **8.11.1** and Kotlin **2.2.20**. `android/gradle/wrapper/gradle-wrapper.properties` pins Gradle **8.14** plus a distribution SHA-256.
- The public source snapshot lacks `android/gradlew`, `android/gradlew.bat`, and `android/gradle/wrapper/gradle-wrapper.jar`. CI generates only these three missing files from a temporary project using the pinned Flutter SDK. **Never overwrite** the real Android Gradle build files or disable wrapper checksum verification to make a build green.
- The public test app uses `org.mewx.wenku8_flutter.source_preview`. A Debug APK is not a production signed Release; a different local debug key may prevent in-place installation.
- Signing the upstream distribution uses a separate, upstream-gated workflow. Do not reuse someone else's keys or silently remove repository checks.

## Procedure

1. Reproduce the exact failing job and step, record commit SHA, target ABI and failing diagnostic. Prefer a concrete GitHub run link to a remembered error.
2. Separate failures by stage:
   - source manifest or restricted component: use `tools/check_public_source.py`;
   - Dart analyzer: inspect `flutter analyze lib test --no-fatal-infos`;
   - Flutter unit tests: inspect `flutter test --no-pub`;
   - Android setup: inspect Java, SDK licenses, Build Tools, CMake/NDK;
   - wrapper/download: check three generated files, Gradle URL and SHA;
   - Gradle / CMake / Kotlin: find first underlying failure, not last `assembleDebug` summary;
   - upload/installation: distinguish an APK file from its ZIP Artifact, and check signature mismatch.
3. Change only the stage responsible. Keep `flutter-ci.yml` (public-source checks) and `android-apk.yml` roles explicit. Update docs when pinning tools or changing upload semantics.
4. Locally, when SDK and wrappers exist:
   ```sh
   flutter pub get
   flutter analyze lib test --no-fatal-infos
   flutter test --no-pub
   flutter build apk --debug --target-platform android-arm64 --no-pub
   ```
5. For a PR, verify the new workflow run on **that PR's head/merge state**. Record exact success/failure per gate, SHA-256 of `app-debug.apk`, Artifact link and expiration if available.
6. Manual Android verification stays separate. For ADB signature conflicts, back up local books and reading state before considering replacement; never recommend data-destructive uninstall as a default.

## Acceptance

- Source policy, analyzer, tests and APK build succeed when intended, with executable evidence (run or logs).
- The ARM64 Artifact contains a nonempty `app-debug.apk`, the expected test application ID, and checksum metadata.
- No credentials committed, no signing identity borrowed, no claims of Release/device validation from a Debug CI pass.
