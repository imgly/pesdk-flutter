import UIKit
import Flutter
import ImglyKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    PESDK.bundleImageBlock = { identifier in
        if identifier == "imgly_icon_save" {
            let data = try? Data(contentsOf: Bundle.main.url(forResource: "imgly_icon_approve_44pt", withExtension: "png")!)
            return UIImage(data: data!)
        }
        return nil
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
