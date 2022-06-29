<p align="center">
  <a href="https://img.ly/photo-sdk?utm_campaign=Projects&utm_source=Github&utm_medium=PESDK&utm_content=Flutter">
    <img src="https://img.ly/static/logos/PE.SDK_Logo.svg" alt="PhotoEditor SDK Logo"/>
  </a>
</p>
<p align="center">
  <a href="https://pub.dev/packages/photo_editor_sdk">
    <img src="https://img.shields.io/pub/v/photo_editor_sdk?color=blue" alt="pub.dev version">
  </a>
  <a href="https://pub.dev/packages/photo_editor_sdk">
    <img src="https://img.shields.io/badge/platforms-android%20|%20ios-lightgrey.svg" alt="Platform support">
  </a>
  <a href="https://twitter.com/imgly">
    <img src="https://img.shields.io/badge/twitter-@PhotoEditorSDK-blue.svg?style=flat" alt="Twitter">
  </a>
</p>

# Flutter plugin for PhotoEditor SDK

## System requirements

- Flutter: 1.20.0
- Dart: 2.12.0
- iOS: 13
- Android: 5 (SDK 21)

## Getting started

Add the plugin package to the `pubspec.yaml` file in your project:

```yaml
dependencies:
  photo_editor_sdk: ^2.6.0
```

Install the new dependency:

```sh
flutter pub get
```

### Known Issues

With version `2.4.0`, we recommend using `compileSdkVersion` not lower than `31` for Android. However, this might interfere with your application's Android Gradle Plugin version if this is set to `4.x`.

If you don't use a newer Android Gradle Plugin version you'll most likely encounter a build error similar to:
```
FAILURE: Build failed with an exception.

* Where:
Build file 'flutter_test_application/android/build.gradle' line: 30

* What went wrong:
A problem occurred evaluating root project 'android'.
> A problem occurred configuring project ':app'.
   > Installed Build Tools revision 31.0.0 is corrupted. Remove and install again using the SDK Manager.

* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output. Run with --scan to get full insights.

* Get more help at https://help.gradle.org
```
**As a workaround you can either:**

1. Upgrade your Android Gradle Plugin version:

    Inside `android/build.gradle` update the version to at least `7.0.0`:
      ```diff
      buildscript {
          ...
          dependencies {
      -       classpath 'com.android.tools.build:gradle:4.1.1'
      +       classpath 'com.android.tools.build:gradle:7.0.0'
              ...
          }
      }
      ```

    After this, you need to update the Gradle version as well in `android/gradle/gradle-wrapper.properties`:
      ```diff
      - distributionUrl=https\://services.gradle.org/distributions/gradle-6.7-all.zip
      + distributionUrl=https\://services.gradle.org/distributions/gradle-7.0.2-all.zip
      ```

2. **Or** create the following symlinks:
  - Inside `/Users/YOUR-USERNAME/Library/Android/sdk/build-tools/31.0.0/`: Create a `dx` symlink for the `d8` file with `ln -s d8 dx`.
  - From there, go to `./lib/` and create a `dx.jar` symlink for the `d8.jar` file with `ln -s d8.jar dx.jar`. 

### Android

1. Add the img.ly repository and plugin by opening the `android/build.gradle` file (**not** `android/app/build.gradle`) and changing the following block:

   ```diff
   buildscript {
   -   ext.kotlin_version = '1.3.50'
   +   ext.kotlin_version = '1.5.32' // Minimum version.
       repositories {
           ...
           mavenCentral()
   +       maven { url "https://artifactory.img.ly/artifactory/imgly" }
           ...
       }
       dependencies {
           ...
   +       classpath 'ly.img.android.sdk:plugin:10.1.1'
           ...
       }
   }
   ```
   In order to update PhotoEditor SDK for Android replace the version string `10.1.1` with a [newer release](https://github.com/imgly/pesdk-android-demo/releases).

2. Still in the `android/build.gradle` file (**not** `android/app/build.gradle`), add these lines at the bottom:

   ```groovy
   allprojects {
       repositories {
           maven { url 'https://artifactory.img.ly/artifactory/imgly' }
       }
   }
   ```

3. In the `android/app/build.gradle` file  (**not** `android/build.gradle`) you will need to modify the `minSdkVersion` to at least `21`. We also recommend to update the `buildToolsVersion` to `31.0.0` or higher as well as the `compileSdkVersion` to `31` or higher:

   ```diff
   android {
   -   compileSdkVersion flutter.compileSdkVersion
   +   compileSdkVersion 31
   +   buildToolsVersion "31.0.0"
       ...
       defaultConfig {
           ...
   -       minSdkVersion flutter.minSdkVersion
   +       minSdkVersion 21
           ...
       }
       ...
   }
   ```

    Depending on your **stable** Flutter SDK version (<= `2.5.0`), your `android/app/build.gradle` file might look a bit different. In this case, please modify it in the following way:

      ```diff
      android {
      -   compileSdkVersion 30
      +   compileSdkVersion 31
      +   buildToolsVersion "31.0.0"
          ...
          defaultConfig {
              ...
      -       minSdkVersion 16
      +       minSdkVersion 21
              ...
          }
          ...
      }
      ```

4. In the same file, configure PhotoEditor SDK for Android by adding the following lines under `apply plugin: "com.android.application"`:

   ```groovy
   apply plugin: 'ly.img.android.sdk'
   apply plugin: 'kotlin-android'

   // Comment out the modules you don't need, to save size.
   imglyConfig {
       modules {
           include 'ui:text'
           include 'ui:focus'
           include 'ui:frame'
           include 'ui:brush'
           include 'ui:filter'
           include 'ui:sticker'
           include 'ui:overlay'
           include 'ui:transform'
           include 'ui:adjustment'
           include 'ui:text-design'

           // This module is big, remove the serializer if you don't need that feature.
           include 'backend:serializer'

           // Remove the asset packs you don't need, these are also big in size.
           include 'assets:font-basic'
           include 'assets:frame-basic'
           include 'assets:filter-basic'
           include 'assets:overlay-basic'
           include 'assets:sticker-shapes'
           include 'assets:sticker-emoticons'

           include 'backend:sticker-smart'
           include 'backend:background-removal'
       }
   }
   ```

### Usage

Import the packages in your `main.dart`:

```dart
import 'package:photo_editor_sdk/photo_editor_sdk.dart';
import 'package:imgly_sdk/imgly_sdk.dart';
```

Each platform requires a separate license file. [Unlock PhotoEditor SDK](./lib/photo_editor_sdk.dart#L13-L22) with a single line of code for both platforms via platform-specific file extensions.

Rename your license files:
- Android license: `pesdk_license.android`
- iOS license: `pesdk_license.ios`

Pass the file path without the extension to the `unlockWithLicense` function to unlock both iOS and Android:

```dart
PESDK.unlockWithLicense("assets/pesdk_license");
```

Open the editor with an image:

```dart
PESDK.openEditor(image: "assets/image.jpg");
```

Please see the [API documentation](https://pub.dev/documentation/photo_editor_sdk) for more details and additional [customization and configuration options](https://pub.dev/documentation/imgly_sdk).

## Example

Please see our [example project](./example) which demonstrates how to use the Flutter plugin for PhotoEditor SDK.

## License Terms

Make sure you have a [commercial license](https://img.ly/pricing?utm_campaign=Projects&utm_source=Github&utm_medium=PESDK&utm_content=Flutter) for PhotoEditor SDK before releasing your app.
A commercial license is required for any app or service that has any form of monetization: This includes free apps with in-app purchases or ad supported applications. Please contact us if you want to purchase the commercial license.

## Support and License

Use our [service desk](https://support.img.ly) for bug reports or support requests. To request a commercial license, please use the [license request form](https://img.ly/pricing?utm_campaign=Projects&utm_source=Github&utm_medium=PESDK&utm_content=Flutter) on our website.
