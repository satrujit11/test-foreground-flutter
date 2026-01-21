import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask.initCommunicationPort();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foreground Service Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ForegroundServicePage(),
    );
  }
}

class ForegroundServicePage extends StatefulWidget {
  const ForegroundServicePage({super.key});

  @override
  State<ForegroundServicePage> createState() => _ForegroundServicePageState();
}

class _ForegroundServicePageState extends State<ForegroundServicePage> {
  bool _isServiceRunning = false;
  int _backgroundCounter = 0;
  String _lastUpdateTime = '';
  final ValueNotifier _taskDataListenable = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _initService();
    _startListening();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _taskDataListenable.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ requires notification permission
      final NotificationPermission notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } else if (Platform.isIOS) {
      // iOS notification permission
      final NotificationPermission notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Background Service',
        channelDescription:
            'This notification keeps the app running in background',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: Platform.isAndroid ? true : false,
        allowWakeLock: Platform.isAndroid ? true : false,
        allowWifiLock: Platform.isAndroid ? true : false,
      ),
    );
  }

  void _startListening() {
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  void _onReceiveTaskData(Object data) {
    _taskDataListenable.value = data;

    if (mounted && data is Map) {
      setState(() {
        _backgroundCounter = data['counter'] ?? 0;
        _lastUpdateTime = data['timestamp'] ?? '';
      });
    }
  }

  Future<void> _startForegroundService() async {
    try {
      await _requestPermissions();

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: '🔄 Background Service Active',
          notificationText: 'Counter: 0 | Starting...',
          notificationButtons: [
            const NotificationButton(id: 'stop_button', text: 'Stop Service'),
          ],
          callback: startCallback,
        );
      }

      if (mounted) {
        setState(() {
          _isServiceRunning = true;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to start service: $e');
    }
  }

  Future<void> _stopForegroundService() async {
    try {
      await FlutterForegroundTask.stopService();

      if (mounted) {
        setState(() {
          _isServiceRunning = false;
          _backgroundCounter = 0;
          _lastUpdateTime = '';
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to stop service: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Foreground Service'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isServiceRunning ? Icons.play_circle : Icons.stop_circle,
                      size: 60,
                      color: _isServiceRunning ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isServiceRunning ? 'Service Running' : 'Service Stopped',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isServiceRunning
                                ? Colors.green
                                : Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isServiceRunning
                          ? '🔄 Background counter active'
                          : '⏹️ Service inactive',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isServiceRunning
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Counter',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_backgroundCounter',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Update',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastUpdateTime.isEmpty ? 'N/A' : _lastUpdateTime,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📱 Notification Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isServiceRunning
                            ? 'Foreground notification active\nUpdates every 5 seconds\nCheck notification shade!'
                            : 'Notifications disabled\nStart service to see updates',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _isServiceRunning ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isServiceRunning
                          ? null
                          : _startForegroundService,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Service'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isServiceRunning
                          ? _stopForegroundService
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Service'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForegroundTaskHandler extends TaskHandler {
  int _counter = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    FlutterForegroundTask.updateService(
      notificationTitle: '🔄 Background Service Active',
      notificationText: 'Counter: 0 | Service Started',
    );

    final data = {
      'counter': 0,
      'timestamp': DateTime.now().toString().substring(11, 19),
      'status': 'started',
    };

    FlutterForegroundTask.sendDataToMain(data);
  }

  void _incrementCounter() {
    _counter++;

    final currentTime = DateTime.now().toString().substring(11, 19);

    FlutterForegroundTask.updateService(
      notificationTitle: '🔄 Background Service Active',
      notificationText: 'Counter: $_counter | Time: $currentTime',
    );

    final data = {
      'counter': _counter,
      'timestamp': currentTime,
      'status': 'running',
    };

    FlutterForegroundTask.sendDataToMain(data);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _incrementCounter();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    FlutterForegroundTask.updateService(
      notificationTitle: '⏹️ Background Service Stopped',
      notificationText:
          'Service ended at ${DateTime.now().toString().substring(11, 19)}',
    );
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_button') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}
