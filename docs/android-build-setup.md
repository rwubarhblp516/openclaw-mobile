# Android Build Setup (WSL/Linux)

This project has a known-good local Android SDK workflow to avoid system SDK and permission issues.

## Recommended configuration

1. Use Gradle `bin` distribution (smaller download):
   - `android/gradle/wrapper/gradle-wrapper.properties`
   - `distributionUrl=https\://services.gradle.org/distributions/gradle-8.3-bin.zip`
2. Use project-local SDK:
   - `android/local.properties`
   - `sdk.dir=/home/jason/projects/openclaw-mobile/.android-sdk`
3. Use Java 17 for Gradle:
   - `android/gradle.properties`
   - `org.gradle.java.home=/usr/lib/jvm/java-17-openjdk-amd64`
4. If needed, set proxy in Gradle (example):
   - `android/gradle.properties`
   - `systemProp.http.proxyHost=192.168.3.84`
   - `systemProp.http.proxyPort=20172`
   - `systemProp.https.proxyHost=192.168.3.84`
   - `systemProp.https.proxyPort=20172`
5. Rust Android bridge is auto-built during Android preBuild:
   - Gradle task: `buildRustAndroid`
   - Output: `android/app/src/main/jniLibs/arm64-v8a/librust_lib.so`

## One-time local SDK bootstrap

```bash
mkdir -p .android-sdk/cmdline-tools/latest
curl -L https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o /tmp/commandlinetools-linux.zip
unzip -q /tmp/commandlinetools-linux.zip -d /tmp/cmdline-tools-extract
cp -r /tmp/cmdline-tools-extract/cmdline-tools/* .android-sdk/cmdline-tools/latest/
```

Accept licenses and install required packages:

```bash
yes | .android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=.android-sdk --licenses
.android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=.android-sdk "platform-tools" "platforms;android-35" "platforms;android-34" "build-tools;33.0.1"
.android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=.android-sdk "ndk;26.3.11579264"
```

Install Rust Android toolchain once:

```bash
rustup target add aarch64-linux-android
cargo install cargo-ndk
```

## Build and run

```bash
flutter build apk --debug
flutter run -d <device-id>
```

## Troubleshooting

1. Stuck on `Running Gradle task 'assembleDebug'...`
   - Usually first-time Gradle distribution download.
   - Prefer `gradle-8.3-bin.zip` over `-all.zip`.
2. SDK license errors (`License for package ... not accepted`)
   - Ensure build uses `.android-sdk` and rerun `sdkmanager --licenses`.
3. `JdkImageTransform` / `jlink` failure with Java 21
   - Use Java 17 via `org.gradle.java.home`.
4. `RustLib.init failed: ... librust_lib.so not found`
   - Ensure `buildRustAndroid` runs (it is attached to `preBuild`).
   - Confirm output exists at `android/app/src/main/jniLibs/arm64-v8a/librust_lib.so`.
