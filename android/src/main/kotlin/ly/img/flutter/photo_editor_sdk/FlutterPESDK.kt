package ly.img.flutter.photo_editor_sdk

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.annotation.NonNull

import java.io.File
import org.json.JSONObject

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import ly.img.android.AuthorizationException

import ly.img.android.IMGLY
import ly.img.android.PESDK
import ly.img.android.pesdk.PhotoEditorSettingsList
import ly.img.android.pesdk.backend.decoder.ImageSource
import ly.img.android.pesdk.backend.model.state.LoadSettings
import ly.img.android.pesdk.kotlin_extension.continueWithExceptions
import ly.img.android.pesdk.utils.UriHelper
import ly.img.android.sdk.config.*
import ly.img.android.pesdk.backend.encoder.Encoder
import ly.img.android.pesdk.backend.model.EditorSDKResult
import ly.img.android.pesdk.utils.ThreadUtils
import ly.img.android.serializer._3.IMGLYFileWriter
import ly.img.android.serializer._3.type.FileMapper
import ly.img.android.serializer._3.type.IMGLYJsonReader

import ly.img.flutter.imgly_sdk.FlutterIMGLY
import java.util.UUID

/**
 * FlutterPESDK
 *
 */
class FlutterPESDK: FlutterIMGLY() {

  companion object {
    // This number must be unique. It is public to allow client code to change it if the same value is used elsewhere.
    var EDITOR_RESULT_ID = 29065
  }

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    super.onAttachedToEngine(binding)

    channel = MethodChannel(binding.binaryMessenger, "photo_editor_sdk")
    channel.setMethodCallHandler(this)
    IMGLY.initSDK(binding.applicationContext)
    IMGLY.authorize()
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (this.result != null) {
      result.error("Multiple requests.", "Cancelled due to multiple requests.", null)
      return
    }

    if (call.method == "openEditor") {
      var config = call.argument<MutableMap<String, Any>>("configuration")
      var photo: String? = null
      val serialization = call.argument<String>("serialization")

      if (config != null) {
        config = this.resolveAssets(config)
      }
      config = config as? HashMap<String, Any>

      val imageValues = call.argument<String>("image")
      if (imageValues != null) {
        photo = EmbeddedAsset(imageValues).resolvedURI
      }

      if (photo != null) {
        this.result = result
        this.present(photo, config, serialization)
      } else {
        if (serialization != null) {
          val json = IMGLYJsonReader.readJson(serialization, true)
          val mappedFile = FileMapper.readFrom(json)
          var imageData = mappedFile.image?.data
          if (imageData != null) {
            imageData = "data:base64,$imageData"
            this.result = result
            this.present(imageData, config, serialization)
          } else {
            result.error("PE.SDK", "The specified serialization did not include a photo.", null)
            return
          }
        } else {
          result.error("PE.SDK", "No image has been specified or included in the serialization.", null)
          return
        }
      }
    } else if (call.method == "unlock") {
      val license = call.argument<String>("license")
      this.result = result
      this.resolveLicense(license)
    } else {
      result.notImplemented()
    }
  }

  /**
   * Configures and presents the editor.
   *
   * @param asset The image source as *String* which should be loaded into the editor.
   * @param config The *Configuration* to configure the editor with as if any.
   * @param serialization The serialization to load into the editor if any.
   */
  override fun present(asset: String, config: HashMap<String, Any>?, serialization: String?) {
    val configuration = ConfigLoader.readFrom(config ?: mapOf())
    val settingsList = PhotoEditorSettingsList(configuration.export?.serialization?.enabled == true)
    configuration.applyOn(settingsList)
    currentConfig = configuration

    settingsList.configure<LoadSettings> { loadSettings ->
      asset.also {
        if (it.startsWith("data:")) {
          loadSettings.source = UriHelper.createFromBase64String(it.substringAfter("base64,"))
        } else {
          val potentialFile = continueWithExceptions { File(it) }
          if (potentialFile?.exists() == true) {
            loadSettings.source = Uri.fromFile(potentialFile)
          } else {
            loadSettings.source = ConfigLoader.parseUri(it)
          }
        }
      }
    }

    applyTheme(settingsList, configuration.theme)

    readSerialisation(settingsList, serialization, false)
    startEditor(settingsList, EDITOR_RESULT_ID)
  }

  /**
   * Unlocks the SDK with a stringified license.
   *
   * @param license The license as a *String*.
   */
  override fun unlockWithLicense(license: String) {
    try {
      PESDK.initSDKWithLicenseData(license)
      IMGLY.authorize()
      this.result?.success(null)
      this.result = null
    } catch (e: AuthorizationException) {
      this.result?.error("PE.SDK", "The license is invalid.", e.message)
      this.result = null
    }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    val intentData = try {
      data?.let { EditorSDKResult(it) }
    } catch (e: EditorSDKResult.NotAnImglyResultException) {
      null
    } ?: return false // If intentData is null the result is not from us.

    if (resultCode == Activity.RESULT_CANCELED && requestCode == EDITOR_RESULT_ID) {
      currentActivity?.runOnUiThread {
        this.result?.success(null)
        this.result = null
      }
      return true
    } else if (resultCode == Activity.RESULT_OK && requestCode == EDITOR_RESULT_ID) {
      ThreadUtils.runAsync {
        val serializationConfig = currentConfig?.export?.serialization
        val resultUri = intentData.resultUri
        val sourceUri = intentData.sourceUri

        var serialization: Any? = null
        if (serializationConfig?.enabled == true) {
          val settingsList = intentData.settingsList
          skipIfNotExists {
            settingsList.let { settingsList ->
              if (serializationConfig.embedSourceImage == true) {
                Log.e("IMG.LY SDK", "EmbedSourceImage is currently not supported by the Android SDK")
              }
              serialization = when (serializationConfig.exportType) {
                SerializationExportType.FILE_URL -> {
                  val uri = serializationConfig.filename?.let {
                    Uri.parse("$it.json")
                  } ?: Uri.fromFile(File.createTempFile("serialization-" + UUID.randomUUID().toString(), ".json"))
                  Encoder.createOutputStream(uri).use { outputStream ->
                    IMGLYFileWriter(settingsList).writeJson(outputStream)
                  }
                  uri.toString()
                }
                SerializationExportType.OBJECT -> {
                  jsonToMap(JSONObject(IMGLYFileWriter(settingsList).writeJsonAsString())) as Any?
                }
              }
            }
            settingsList.release()
          } ?: run {
            Log.e("IMG.LY SDK", "You need to include 'backend:serializer' Module, to use serialisation!")
          }
        }

        val map = mutableMapOf<String, Any?>()
        map["image"] = when(currentConfig?.export?.image?.exportType) {
          ImageExportType.DATA_URL -> resultUri.let {
            val imageSource = ImageSource.create(it)
            "data:${imageSource.imageFormat.mimeType};base64,${imageSource.asBase64}"
          }
          ImageExportType.FILE_URL -> resultUri?.toString()
          else -> resultUri.toString()
        }
        map["hasChanges"] = (sourceUri?.path != resultUri?.path)
        map["serialization"] = serialization
        currentActivity?.runOnUiThread {
          this.result?.success(map)
          this.result = null
        }
      }
      return true
    }
    return false
  }
}
