import Flutter
import UIKit
import CoreServices
import ImglyKit
import imgly_sdk

@available(iOS 9.0, *)
public class FlutterPESDK: FlutterIMGLY, FlutterPlugin, PhotoEditViewControllerDelegate {

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
            self.result?(FlutterError(code: "multiple_requests", message: "Cancelled due to multiple requests.", details: nil))
            self.result = nil
        }

        if call.method == "openEditor" {
            let configuration = arguments["configuration"] as? IMGLYDictionary
            let serialization = arguments["serialization"] as? IMGLYDictionary
            self.result = result

            var photo: Photo?
            if let assetObject = arguments["image"] as? String,
               let assetURL = EmbeddedAsset(from: assetObject).resolvedURL, let url = URL(string: assetURL) {
                photo = Photo(url: url)
            } else {
                result(FlutterError(code: "Could not load image.", message: nil, details: nil))
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
                    deserializationResult = Deserializer.deserialize(data: finalData, imageDimensions: photo_.size, assetCatalog: configurationData?.assetCatalog ?? .shared)
                } else {
                    deserializationResult = Deserializer._objCDeserialize(data: finalData, assetCatalog: configurationData?.assetCatalog ?? .shared)
                    if let serializationPhoto = deserializationResult?.photo {
                        finalPhotoAsset = Photo.from(photoRepresentation: serializationPhoto)
                    } else {
                        self.result?(FlutterError(code: "Photo must not be nil.", message: "The specified serialization did not include a photo.", details: nil))
                        return nil
                    }
                }
                photoEditModel = deserializationResult?.model ?? photoEditModel
            }

            guard let finalPhoto = finalPhotoAsset else { return  nil }

            if let configuration = configurationData {
                editor = PhotoEditViewController(photoAsset: finalPhoto, configuration: configuration, photoEditModel: photoEditModel)
            } else {
                editor = PhotoEditViewController(photoAsset: finalPhoto, photoEditModel: photoEditModel)
            }
            editor.delegate = self
            editor.modalPresentationStyle = .fullScreen
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
}

// MARK: - Delegate

/// The delegate for the `PhotoEditViewController`.
@available(iOS 9.0, *)
extension FlutterPESDK {

    /// Delegate function called when the `PhotoEditViewController` has successfully exported the image.
    /// - Parameter photoEditViewController: The editor who has finished exporting.
    /// - Parameter image: The exported image.
    /// - Parameter data: The image data.
    public func photoEditViewController(_ photoEditViewController: PhotoEditViewController, didSave image: UIImage, and data: Data) {
        let options = photoEditViewController.configuration.photoEditViewControllerOptions
        var imageData: Data? = data

        if imageData != nil {
            switch options.outputImageFileFormat {
            case .png:
                imageData = image.pngData()
                break
            case .jpeg:
                imageData = image.jpegData(compressionQuality: options.compressionQuality)
                break
            default:
                break
            }
        }

        var imageString: NSString?
        var serialization: Any?

        if imageData?.isEmpty == false {
            if self.exportType == IMGLYConstants.kExportTypeFileURL {
                guard let fileURL = self.exportFile else {
                    self.result?(FlutterError(code: "Export type must not be nil.", message: "No valid export type has been specified.", details: self.exportFile))
                    return
                }
                do {
                    try imageData?.IMGLYwriteToUrl(fileURL, andCreateDirectoryIfNeeded: true)
                    imageString = (self.exportFile?.absoluteString ?? "nil") as NSString
                } catch let error {
                    self.result?(FlutterError(code: "Image could not be saved.", message: "Error message: \(error.localizedDescription)", details: error))
                    return
                }
            } else if self.exportType == IMGLYConstants.kExportTypeDataURL {
                let mediaType: NSString? = UTTypeCopyPreferredTagWithClass(options.outputImageFileFormatUTI, kUTTagClassMIMEType)?.takeRetainedValue()
                imageString = String(format: "data:%@;base64,%@", mediaType!, imageData!.base64EncodedString()) as NSString
            }
        }

        if self.serializationEnabled == true {
            guard let serializationData = photoEditViewController.serializedSettings(withImageData: self.serializationEmbedImage ?? false) else {
                return
            }
            if self.serializationType == IMGLYConstants.kExportTypeFileURL {
                guard let exportURL = self.serializationFile else {
                    self.result?(FlutterError(code: "Serialization failed.", message: "The URL must not be nil.", details: nil))
                    return
                }
                do {
                    try serializationData.IMGLYwriteToUrl(exportURL, andCreateDirectoryIfNeeded: true)
                    serialization = self.serializationFile?.absoluteString
                } catch let error {
                    self.result?(FlutterError(code: "Serialization failed.", message: error.localizedDescription, details: error))
                }
            } else if self.serializationType == IMGLYConstants.kExportTypeObject {
                do {
                    serialization = try JSONSerialization.jsonObject(with: serializationData, options: .init(rawValue: 0))
                } catch let error {
                    self.result?(FlutterError(code: "Serialization failed.", message: error.localizedDescription, details: error))
                }
            }
        }

        self.dismiss(mediaEditViewController: photoEditViewController, animated: true) {
            let res: [String: Any?] = ["image": imageString ?? "no image exported", "hasChanges": photoEditViewController.hasChanges, "serialization": serialization]
            self.result?(res)
        }
    }

    /// Delegate function that is called if the `PhotoEditViewController` did fail
    /// to export the image.
    ///
    /// - Parameter photoEditViewController: The editor that failed to export.
    public func photoEditViewControllerDidFailToGeneratePhoto(_ photoEditViewController: PhotoEditViewController) {
        self.dismiss(mediaEditViewController: photoEditViewController, animated: true) {
            self.result?(FlutterError(code: "editor_failed", message: "The editor did fail to generate the image.", details: nil))
        }
    }

    /// Delegate function that is called if the `PhotoEditViewController` has
    /// been cancelled.
    ///
    /// - Parameter photoEditViewController: The editor that was cancelled.
    public func photoEditViewControllerDidCancel(_ photoEditViewController: PhotoEditViewController) {
        self.dismiss(mediaEditViewController: photoEditViewController, animated: true) {
            self.result?(nil)
        }
    }
}
