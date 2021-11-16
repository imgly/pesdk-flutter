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

## Getting started

Add the plugin package to the `pubspec.yaml` file in your project:

```yaml
dependencies:
  photo_editor_sdk: ^2.2.0
```

Install the new dependency:

```sh
flutter pub get
```

### Android

1. Because PhotoEditor SDK for Android is quite large, there is a high chance that you will need to enable Multidex for your project as follows:

   Open the `android/app/build.gradle file` (**not** `android/build.gradle`) and add these lines at the end:
   ```groovy
   android {
     defaultConfig {
         multiDexEnabled true
     }
   }
   dependencies {
       implementation 'androidx.multidex:multidex:2.0.1'
   }
   ```

2. Add the img.ly repository and plugin by opening the `android/build.gradle` file (**not** `android/app/build.gradle`) and adding these lines at the top:
   ```groovy
   buildscript {
       repositories {
           mavenCentral()
           maven { url "https://artifactory.img.ly/artifactory/imgly" }
       }
       dependencies {
           classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.4.10"
           classpath 'ly.img.android.sdk:plugin:9.1.0'
       }
   }
   ```
   In order to update PhotoEditor SDK for Android replace the version string `9.1.0` with a [newer release](https://github.com/imgly/pesdk-android-demo/releases).

3. Still in the `android/build.gradle` file (**not** `android/app/build.gradle`), add these lines at the bottom:

   ```groovy
   allprojects {
       repositories {
           maven { url 'https://artifactory.img.ly/artifactory/imgly' }
       }
   }
   ```

4. Configure PhotoEditor SDK for Android by opening the `android/app/build.gradle` file  (**not** `android/build.gradle`) and adding the following lines under `apply plugin: "com.android.application"`:
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
