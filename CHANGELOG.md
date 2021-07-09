## [2.0.0]

### Added

* Added null safety support for all three plugins.
* [imgly_sdk] Added integration and documentation for new video composition, video library and audio library tools.
* [imgly_sdk] Added missing code examples in the API documentation.
* [video_editor_sdk] Added integration and documentation for new video composition, video library and audio library tools.

### Changed

* [imgly_sdk] Updated identifier documentation for replaced and new fonts.
* [video_editor_sdk] The named parameter `video` of the `VESDK.openEditor` method now expects a `Video` instead of a `String`.

### Fixed

* Fixed crash when integrating all three plugins in the same project on Android.
* [imgly_sdk] Fixed some custom assets would not be resolved correctly on Android.
* [imgly_sdk] Fixed code examples in API documentation for using existing assets that are provided by the SDK.
* [imgly_sdk] Fixed thumbnail would not be loaded for a custom `Overlay` on iOS.

## [1.0.1]

### Added

* [photo_editor_sdk] Initial release.
* [video_editor_sdk] Initial release.

### Fixed

* [imgly_sdk] Fixed custom stickers and filters would not be resolved.

## [1.0.0]

### Added

* [imgly_sdk] Initial release.
