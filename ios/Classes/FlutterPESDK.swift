import Flutter
import UIKit
import CoreServices
import ImglyKit
import imgly_sdk

@available(iOS 13.0, *)
public class FlutterPESDK: FlutterIMGLY, FlutterPlugin, PhotoEditViewControllerDelegate {

    // MARK: - Typealias

    /// A closure to modify a new `PhotoEditViewController` before it is presented on screen.
    public typealias PESDKWillPresentBlock = (_ photoEditViewController: PhotoEditViewController) -> Void

    // MARK: - Properties

    /// Set this closure to modify a new `PhotoEditViewController` before it is presented on screen.
    public static var willPresentPhotoEditViewController: PESDKWillPresentBlock?

    // MARK: - Flutter Channel

    /// Registers for the channel in order to communicate with the
    /// Flutter plugin.
    /// - Parameter registrar: The `FlutterPluginRegistrar` used to register.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "photo_editor_sdk", binaryMessenger: registrar.messenger())
        let instance = FlutterPESDK()
        registrar.addMethodCallDelegate(instance, channel: channel)
        FlutterPESDK.registrar = registrar
        FlutterPESDK.methodeChannel = channel
    }

    /// Retrieves the methods and initiates the fitting behavior.
    /// - Parameter call: The `FlutterMethodCall` containig the information about the method.
    /// - Parameter result: The `FlutterResult` to return to the Flutter plugin.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? IMGLYDictionary else { return }

        if self.result != nil {
            result(FlutterError(code: "Multiple requests.", message: "Cancelled due to multiple requests.", details: nil))
            return
        }

        if call.method == "openEditor" {
            let configuration = arguments["configuration"] as? IMGLYDictionary
            let serialization = arguments["serialization"] as? IMGLYDictionary
            self.result = result

            var photo: Photo?
            if let assetObject = arguments["image"] as? String,
               let assetURL = EmbeddedAsset(from: assetObject).resolvedURL, let url = URL(string: assetURL) {
                photo = Photo(url: url)
            }
            self.present(photo: photo, configuration: configuration, serialization: serialization)
        } else if call.method == "unlock" {
            guard let license = arguments["license"] as? String else { return }
            self.result = result
            self.unlockWithLicense(with: license)
        }
    }

    // MARK: - Presenting editor

    /// Presents an instance of `PhotoEditViewController`.
    /// - Parameter photo: The `Photo` to initialize the editor with.
    /// - Parameter configuration: The configuration for the editor in as `IMGLYDictionary`
    /// - Parameter serialization: The serialization as `IMGLYDictionary`.
    private func present(photo: Photo?, configuration: IMGLYDictionary?, serialization: IMGLYDictionary?) {
        self.present(mediaEditViewControllerBlock: { (configurationData, serializationData) -> MediaEditViewController? in

            var finalPhotoAsset: Photo? = photo
            var photoEditModel = PhotoEditModel()
            var editor: PhotoEditViewController

            if let finalData = serializationData {
                var deserializationResult: Deserializer.DeserializationResult?
                if let photo_ = photo {
                    deserializationResult = Deserializer.deserialize(data: finalData, imageDimensions: photo_.size, assetCatalog: configurationData?.assetCatalog ?? .defaultItems)
                } else {
                    deserializationResult = Deserializer._objCDeserialize(data: finalData, assetCatalog: configurationData?.assetCatalog ?? .defaultItems)
                    if let serializationPhoto = deserializationResult?.photo {
                        finalPhotoAsset = Photo.from(photoRepresentation: serializationPhoto)
                    } else {
                        self.result?(FlutterError(code: "Photo must not be nil.", message: "The specified serialization did not include a photo.", details: nil))
                        self.result = nil
                        return nil
                    }
                }
                photoEditModel = deserializationResult?.model ?? photoEditModel
            }

            guard let finalPhoto = finalPhotoAsset else {
                self.result?(FlutterError(code: "Photo must not be nil.", message: "No image has been specified or included in the serialization.", details: nil))
                self.result = nil
                return nil
            }

            if let configuration = configurationData {
                editor = PhotoEditViewController.makePhotoEditViewController(photoAsset: finalPhoto, configuration: configuration, photoEditModel: photoEditModel)
            } else {
                editor = PhotoEditViewController.makePhotoEditViewController(photoAsset: finalPhoto, photoEditModel: photoEditModel)
            }
            editor.delegate = self
            editor.modalPresentationStyle = .fullScreen

            FlutterPESDK.willPresentPhotoEditViewController?(editor)

            return editor
        }, utiBlock: { (configurationData) -> CFString in
            return (configurationData?.photoEditViewControllerOptions.outputImageFileFormatUTI ?? kUTTypeJPEG)
        }, configurationData: configuration, serialization: serialization)
    }

    // MARK: - Licensing

    /// Unlocks the license from a url.
    /// - Parameter url: The URL where the license file is located.
    public override func unlockWithLicenseFile(at url: URL) {
        DispatchQueue.main.async {
            do {
                try PESDK.unlockWithLicense(from: url)
                self.result = nil
            } catch let error {
                self.handleLicenseError(with: error as NSError)
            }
        }
    }

    private func handleError(_ photoEditViewController: PhotoEditViewController, code: String, message: String?, details: Any?) {
        self.dismiss(mediaEditViewController: photoEditViewController, animated: true) {
            self.result?(FlutterError(code: code, message: message, details: details))
            self.result = nil
        }
    }
}

// MARK: - Delegate

/// The delegate for the `PhotoEditViewController`.
@available(iOS 13.0, *)
extension FlutterPESDK {
    /// Delegate function called when the `PhotoEditViewController` has successfully exported the image.
    /// - Parameter photoEditViewController: The editor who has finished exporting.
    /// - Parameter result: The `PhotoEditorResult` from the editor.
    public func photoEditViewControllerDidFinish(_ photoEditViewController: PhotoEditViewController, result: PhotoEditorResult) {
        guard let uti = result.output.uti else {
            self.handleError(photoEditViewController, code: "Image could not be saved.", message: nil, details: nil)
            return
        }

        let imageData = result.output.data
        var imageString: String?
        var serialization: Any?

        if imageData.isEmpty == false {
            if self.exportType == IMGLYConstants.kExportTypeFileURL {
                guard let fileURL = self.exportFile else {
                    self.handleError(photoEditViewController, code: "Export type must not be nil.", message: "No valid export type has been specified.", details: self.exportFile)
                    return
                }
                do {
                    try imageData.IMGLYwriteToUrl(fileURL, andCreateDirectoryIfNeeded: true)
                    imageString = fileURL.absoluteString
                } catch let error {
                    self.handleError(photoEditViewController, code: "Image could not be saved.", message: "Error message: \(error.localizedDescription)", details: error)
                    return
                }
            } else if self.exportType == IMGLYConstants.kExportTypeDataURL {
                if let mediaType = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType)?.takeRetainedValue() as? NSString {
                    imageString = String(format: "data:%@;base64,%@", mediaType, imageData.base64EncodedString())
                } else {
                    self.handleError(photoEditViewController, code: "Image could not be saved.", message: "The output UTI could not be read.", details: nil)
                    return
                }
            }
        }

        if self.serializationEnabled == true {
            guard let serializationData = photoEditViewController.serializedSettings(withImageData: self.serializationEmbedImage ?? false) else {
                return
            }
            if self.serializationType == IMGLYConstants.kExportTypeFileURL {
                guard let exportURL = self.serializationFile else {
                    self.handleError(photoEditViewController, code: "Serialization failed.", message: "The URL must not be nil.", details: nil)
                    return
                }
                do {
                    try serializationData.IMGLYwriteToUrl(exportURL, andCreateDirectoryIfNeeded: true)
                    serialization = self.serializationFile?.absoluteString
                } catch let error {
                    self.handleError(photoEditViewController, code: "Serialization failed.", message: error.localizedDescription, details: error)
                    return
                }
            } else if self.serializationType == IMGLYConstants.kExportTypeObject {
                do {
                    serialization = try JSONSerialization.jsonObject(with: serializationData, options: .init(rawValue: 0))
                } catch let error {
                    self.handleError(photoEditViewController, code: "Serialization failed.", message: error.localizedDescription, details: error)
                    return
                }
            }
        }

        self.dismiss(mediaEditViewController: photoEditViewController, animated: true) {
            let res: [String: Any?] = ["image": imageString ?? "no image exported", "hasChanges": result.status == .renderedWithChanges, "serialization": serialization]
            self.result?(res)
            self.result = nil
        }
    }

    /// Delegate function that is called if the `PhotoEditViewController` did fail
    /// to export the image.
    ///
    /// - Parameter photoEditViewController: The editor that failed to export.
    /// - Parameter error: The `PhotoEditorError` that caused the failure.
    public func photoEditViewControllerDidFail(_ photoEditViewController: PhotoEditViewController, error: PhotoEditorError) {
        self.handleError(photoEditViewController, code: "Editor failed", message: "The editor did fail to generate the image.", details: error)
    }

    /// Delegate function that is called if the `PhotoEditViewController` has
    /// been cancelled.
    ///
    /// - Parameter photoEditViewController: The editor that was cancelled.
    public func photoEditViewControllerDidCancel(_ photoEditViewController: PhotoEditViewController) {
        self.dismiss(mediaEditViewController: photoEditViewController, animated: true) {
            self.result?(nil)
            self.result = nil
        }
    }
}
