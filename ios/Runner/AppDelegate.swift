import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure AVAudioSession for audio playback and recording
    do {
      let audioSession = AVAudioSession.sharedInstance()
      // Use playAndRecord category to support both recording and playback
      // Set options to allow playback through speaker and mix with other audio
      try audioSession.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .duckOthers]
      )
      try audioSession.setActive(true)
      print("✅ Audio session configured successfully for playback and recording")
    } catch {
      print("❌ Failed to set audio session category: \(error.localizedDescription)")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // Reconfigure audio session when app becomes active to ensure speaker output
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .duckOthers]
      )
      try audioSession.setActive(true)
      print("✅ Audio session reconfigured on app active for speaker output")
    } catch {
      print("❌ Failed to reconfigure audio session on app active: \(error.localizedDescription)")
    }
  }
}
