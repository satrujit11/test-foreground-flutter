import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register background tasks for iOS
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.example.backgroundTest.foreground_task",
      using: nil
    )
    
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.example.backgroundTest.background_refresh",
      using: nil
    )
    
    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        print("Notification permission granted")
      } else if let error = error {
        print("Notification permission error: \(error)")
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Schedule background app refresh when app enters background
    scheduleBackgroundAppRefresh()
  }
  
  private func scheduleBackgroundAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.backgroundTest.background_refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now
    
    do {
      try BGTaskScheduler.shared.submit(request)
      print("Background app refresh scheduled")
    } catch {
      print("Failed to schedule background app refresh: \(error)")
    }
  }
}
