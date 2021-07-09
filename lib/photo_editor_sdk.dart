import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:imgly_sdk/imgly_sdk.dart';

/// The plugin class for the photo_editor_sdk plugin.
class PESDK {
  /// The `MethodChannel`.
  static const MethodChannel _channel = MethodChannel('photo_editor_sdk');

  /// Unlocks the SDK with a license file from the assets.
  /// The [path] input should be a relative path to the license
  /// file(s) as specified in your `pubspec.yaml` file.
  /// If you want to unlock the SDK for both iOS and Android, you need
  /// to include one license for each platform with the same name, but where
  /// the iOS license has `.ios` as its file extension and the
  /// Android license has `.android` as its file extension.
  static void unlockWithLicense(String path) async {
    await _channel.invokeMethod('unlock', <String, dynamic>{'license': path});
  }

  /// Opens a new photo editor.
  ///
  /// Modally opens the editor with an image from the given [image] source.
  /// The editor can be customized with the [configuration].
  /// The [serialization] restores a previous state of the editor
  /// by re-applying all modifications to the image.
  /// The [image] source should either be a full path, an URI
  /// or if it is an asset the relative path as specified in
  /// your `pubspec.yaml` file. If this parameter is `null`,
  /// the [serialization] must not be `null` and it must contain
  /// an embedded source image.
  /// Once finished, the editor either returns a
  /// [PhotoEditorResult] or `null` if the editor was dismissed without
  /// exporting the image.
  static Future<PhotoEditorResult?> openEditor(
      {String? image,
      Configuration? configuration,
      Map<String, dynamic>? serialization}) async {
    final result = await _channel.invokeMethod('openEditor', {
      'image': image,
      'configuration': configuration?.toJson(),
      'serialization': serialization == null
          ? null
          : Platform.isIOS
              ? serialization
              : jsonEncode(serialization)
    });
    return result == null
        ? null
        : PhotoEditorResult._fromJson(Map<String, dynamic>.from(result));
  }
}

/// Returned if an editor has completed exporting.
class PhotoEditorResult {
  /// Creates a new [PhotoEditorResult].
  PhotoEditorResult._(this.image, this.hasChanges, this.serialization);

  /// The edited image.
  final String image;

  /// Indicating whether the image has been
  /// changed at all.
  final bool hasChanges;

  /// The serialization contains the applied changes. This is only
  /// returned in case `Configuration.export.serialization.enabled` is
  /// set to `true`.
  /// The serialization can either be the path of the serialization file as
  /// a [String] in case that `Configuration.export.serialization.exportType`
  /// is set to [SerializationExportType.fileUrl]
  /// or an object if `Configuration.export.serialization.exportType`
  /// is set to [SerializationExportType.object].
  final dynamic serialization;

  /// Creates a [PhotoEditorResult] from the [json] map.
  factory PhotoEditorResult._fromJson(Map<String, dynamic> json) =>
      PhotoEditorResult._(
          json["image"], json["hasChanges"], json["serialization"]);

  /// Converts the [PhotoEditorResult] for JSON parsing.
  Map<String, dynamic> toJson() => {
        "image": image,
        "hasChanges": hasChanges,
        "serialization": serialization
      };
}
