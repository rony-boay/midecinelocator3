import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(
        tz.getLocation('Asia/Karachi')); // Set the local timezone to PST

    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iOSInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iOSInitializationSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('Notification received: ${response.payload}');
      },
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> showInstantNotification(String title, String body) async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'instant_notification_channel_id',
        'Instant Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      _generateSafeNotificationId(),
      title,
      body,
      platformChannelSpecifics,
      payload: 'instant_notification',
    );
  }

  static Future<void> scheduleDailyNotification(
      String title, String body, TimeOfDay time) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour - 5,
      time.minute,
    );

    // If the scheduled time is before the current time, schedule for the next day
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final int id = _generateSafeNotificationId();
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_notification_channel_id',
          'Daily Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${id}|${scheduledDate.millisecondsSinceEpoch}',
    );
  }

  static Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  static int _generateSafeNotificationId() {
    final Random random = Random();
    return random.nextInt(2147483647); // 32-bit integer range
  }
}

class ScheduleNotificationScreen extends StatefulWidget {
  const ScheduleNotificationScreen({super.key});

  @override
  _ScheduleNotificationScreenState createState() =>
      _ScheduleNotificationScreenState();
}

class _ScheduleNotificationScreenState
    extends State<ScheduleNotificationScreen> {
  TimeOfDay scheduleTime = TimeOfDay.now();
  List<Map<String, dynamic>> scheduledNotifications = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadScheduledNotifications();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadScheduledNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? notifications =
        prefs.getStringList('scheduledNotifications');
    if (notifications != null) {
      setState(() {
        scheduledNotifications = notifications.map((notificationString) {
          final parts = notificationString.split('|');
          return {
            'id': int.parse(parts[0]),
            'scheduledDate':
                DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1])),
          } as Map<String, dynamic>;
        }).toList();
      });
    }
  }

  Future<void> _saveScheduledNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> notifications =
        scheduledNotifications.map((notification) {
      return '${notification['id']}|${notification['scheduledDate'].millisecondsSinceEpoch}';
    }).toList();
    await prefs.setStringList('scheduledNotifications', notifications);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Notification'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Medicine Reminder',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                      ),
                      icon: const Icon(Icons.access_time, color: Colors.white),
                      onPressed: () => _selectTime(context),
                      label: const Text(
                        'Select Time',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                      ),
                      icon:
                          const Icon(Icons.notifications, color: Colors.white),
                      onPressed: _scheduleDailyNotification,
                      label: const Text(
                        'Schedule Daily Notification',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    // ElevatedButton.icon(
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.teal,
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     padding: const EdgeInsets.symmetric(
                    //         vertical: 12, horizontal: 16),
                    //   ),
                    //   icon: const Icon(Icons.notifications_active,
                    //       color: Colors.white),
                    //   onPressed: _showTestNotification,
                    //   label: const Text(
                    //     'Test Notification',
                    //     style: TextStyle(fontSize: 18, color: Colors.white),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                itemCount: scheduledNotifications.length,
                itemBuilder: (context, index) {
                  final notification = scheduledNotifications[index];
                  final scheduledDate =
                      notification['scheduledDate'] as DateTime;
                  final now = DateTime.now().toLocal(); // Local time
                  final timeRemaining = scheduledDate.difference(now);
                  final hours = timeRemaining.inHours;
                  final minutes = timeRemaining.inMinutes % 60;
                  final seconds = timeRemaining.inSeconds % 60;

                  // Check if the time has passed and update the schedule
                  if (timeRemaining.isNegative) {
                    final newScheduledDate = now.add(const Duration(days: 1));
                    scheduledNotifications[index] = {
                      'id': notification['id'],
                      'scheduledDate': newScheduledDate,
                    };
                    NotificationService.scheduleDailyNotification(
                      'Medicine Reminder',
                      'This is a reminder for your medicine!',
                      TimeOfDay.fromDateTime(newScheduledDate),
                    );
                    _saveScheduledNotifications();
                  }

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      // title: Text(
                      //   'Scheduled: ${_formatDateTime(scheduledDate)}',
                      //   style: const TextStyle(fontSize: 16),
                      // ),
                      subtitle: Text(
                        'Remaining: ${hours}h ${minutes}m ${seconds}s',
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _cancelNotification(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked =
        await showTimePicker(context: context, initialTime: scheduleTime);
    if (picked != null && picked != scheduleTime) {
      setState(() {
        scheduleTime = picked;
      });
    }
  }

  Future<void> _scheduleDailyNotification() async {
    await NotificationService.scheduleDailyNotification(
      'Medicine Reminder',
      'This is a reminder for your medicine!',
      scheduleTime,
    );

    final scheduledDate = tz.TZDateTime(
      tz.local,
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      scheduleTime.hour - 5,
      scheduleTime.minute,
    );

    final notificationId = NotificationService._generateSafeNotificationId();
    setState(() {
      scheduledNotifications.add({
        'id': notificationId,
        'scheduledDate': scheduledDate,
      });
    });

    await _saveScheduledNotifications();
  }

  // void _showTestNotification() {
  //   NotificationService.showInstantNotification(
  //     'Test Notification',
  //     'This is a test notification.',
  //   );
  // }

  Future<void> _cancelNotification(int index) async {
    final notification = scheduledNotifications[index];
    final int notificationId = notification['id'];
    await NotificationService.cancelNotification(notificationId);
    setState(() {
      scheduledNotifications.removeAt(index);
    });

    await _saveScheduledNotifications(); // Remove from shared preferences
  }
}
