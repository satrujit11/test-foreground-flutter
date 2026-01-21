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
    ) { task in
      self.handleForegroundTask(task as! BGAppRefreshTaskRequest)
    }
    
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.example.backgroundTest.background_refresh",
      using: nil
    ) { task in
      self.handleBackgroundRefresh(task as! BGAppRefreshTaskRequest)
    }
    
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
  
  private func handleForegroundTask(_ task: BGAppRefreshTaskRequest) {
    print("Foreground task started")
    
    task.expirationHandler = {
      print("Foreground task expired")
      task.setTaskCompleted(success: false)
    }
    
    // Perform the foreground task work
    DispatchQueue.global(qos: .background).async {
      // Add your foreground task logic here
      // This could communicate with Flutter foreground task plugin
      print("Executing foreground task work")
      
      // Simulate some work
      Thread.sleep(forTimeInterval: 2)
      
      DispatchQueue.main.async {
        print("Foreground task completed")
        task.setTaskCompleted(success: true)
      }
    }
  }
  
  private func handleBackgroundRefresh(_ task: BGAppRefreshTaskRequest) {
    print("Background refresh task started")
    
    task.expirationHandler = {
      print("Background refresh task expired")
      task.setTaskCompleted(success: false)
    }
    
    // Perform the background refresh work
    DispatchQueue.global(qos: .background).async {
      // Add your background refresh logic here
      // This could communicate with Flutter workmanager plugin
      print("Executing background refresh work")
      
      // Simulate some work
      Thread.sleep(forTimeInterval: 3)
      
      DispatchQueue.main.async {
        print("Background refresh task completed")
        task.setTaskCompleted(success: true)
        
        // Schedule the next background refresh
        self.scheduleBackgroundAppRefresh()
      }
    }
  }
}
