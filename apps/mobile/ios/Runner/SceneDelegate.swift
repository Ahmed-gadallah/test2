import Flutter
import UIKit

/// Hides app content in the iOS app switcher snapshot (invoices contain medicine names).
/// iOS does not allow blocking screenshots; this covers the switcher and screen-recording previews of the snapshot.
class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    guard privacyCover == nil, let window = window else { return }
    let cover = UIView(frame: window.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.backgroundColor = UIColor(red: 0x22 / 255.0, green: 0x24 / 255.0, blue: 0xC6 / 255.0, alpha: 1)
    window.addSubview(cover)
    privacyCover = cover
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
