import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  runApp(JookeboxApp());
}

class JookeboxApp extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jookebox App',
      color: Colors.black,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      debugShowCheckedModeBanner: false,
      home: ReminderPage(),
    );
  }
}

class ReminderPage extends StatefulWidget {
  @override
  _ReminderPageState createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final FlutterLocalNotificationsPlugin _notifPlugin = FlutterLocalNotificationsPlugin();

  String? _selectedDay;
  TimeOfDay? _selectedTime;
  String? _selectedActivity;
  Map<String, List<Map<String, String>>> _reminders = {};

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final List<String> _activities = [
    'Wake up', 'Go to gym', 'Breakfast', 'Meetings', 'Lunch', 'Quick nap', 'Go to library', 'Dinner', 'Go to sleep'
  ];

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initNotifications();
    _loadReminders();
  }

  void _initNotifications() async {
    final androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = IOSInitializationSettings();
    final settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifPlugin.initialize(settings, onSelectNotification: _onSelectNotification);
  }

  Future<void> _onSelectNotification(String? payload) async {
    if (payload != null) {
      debugPrint('Notification payload: $payload');
    }
  }

  Future<void> _loadReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? remindersStr = prefs.getString('reminders');
    if (remindersStr != null) {
      Map<String, dynamic> remindersJson = jsonDecode(remindersStr);
      setState(() {
        _reminders = remindersJson.map((key, value) {
          return MapEntry(key, List<Map<String, String>>.from(value.map((e) => Map<String, String>.from(e))));
        });
      });
    }
  }

  Future<void> _saveReminder(Map<String, String> reminder) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_reminders[_selectedDay!] == null) {
      _reminders[_selectedDay!] = [];
    }
    _reminders[_selectedDay!]!.add(reminder);
    String remindersStr = jsonEncode(_reminders);
    prefs.setString('reminders', remindersStr);
    setState(() {});
  }

  void _scheduleNotification() async {
    if (_selectedDay != null && _selectedTime != null && _selectedActivity != null) {
      final now = DateTime.now();
      final dayOffset = _days.indexOf(_selectedDay!) - (now.weekday - 1);
      final reminderDate = DateTime(now.year, now.month, now.day)
          .add(Duration(days: dayOffset >= 0 ? dayOffset : dayOffset + 7))
          .add(Duration(hours: _selectedTime!.hour, minutes: _selectedTime!.minute));

      if (reminderDate.isBefore(now)) {
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        'reminder_channel',
        'Reminder',
        channelDescription: 'Reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'), // Custom sound for notification
      );

      final iosDetails = IOSNotificationDetails(
        sound: 'notification.aiff', // Ensure you have a corresponding sound file for iOS
      );
      final notifDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifPlugin.zonedSchedule(
        reminderDate.millisecondsSinceEpoch % 100000, // Unique ID for each notification
        'Reminder',
        _selectedActivity,
        tz.TZDateTime.from(reminderDate, tz.local),
        notifDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      final reminder = {
        'day': _selectedDay!,
        'time': _selectedTime!.format(context),
        'activity': _selectedActivity!,
      };
      _saveReminder(reminder);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder set for $_selectedDay at ${_selectedTime!.format(context)}'))
      );


    }
  }

  void _goToRemindersList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RemindersListPage(reminders: _reminders, onDelete: _deleteReminder)),
    );
  }

  void _deleteReminder(String day, int index) async {
    _reminders[day]!.removeAt(index);
    if (_reminders[day]!.isEmpty) {
      _reminders.remove(day);
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String remindersStr = jsonEncode(_reminders);
    prefs.setString('reminders', remindersStr);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'Jookebox App',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: _goToRemindersList,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Day',
                border: OutlineInputBorder(),
              ),
              value: _selectedDay,
              onChanged: (newValue) {
                setState(() {
                  _selectedDay = newValue;
                });
              },
              items: _days.map((day) {
                return DropdownMenuItem(
                  child: Text(day),
                  value: day,
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _selectedTime = time;
                  });
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: _selectedTime == null ? 'Select Time' : _selectedTime!.format(context),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Activity',
                border: OutlineInputBorder(),
              ),
              value: _selectedActivity,
              onChanged: (newValue) {
                setState(() {
                  _selectedActivity = newValue;
                });
              },
              items: _activities.map((activity) {
                return DropdownMenuItem(
                  child: Text(activity),
                  value: activity,
                );
              }).toList(),
            ),
            SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: _scheduleNotification,
                child: Text('Set Reminder'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RemindersListPage extends StatelessWidget {
  final Map<String, List<Map<String, String>>> reminders;
  final Function(String, int) onDelete;

  RemindersListPage({required this.reminders, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Reminders'),
      ),
      body: ListView.builder(
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          String day = reminders.keys.elementAt(index);
          List<Map<String, String>> dayReminders = reminders[day]!;
          return ExpansionTile(
            title: Text(day),
            children: dayReminders.map((reminder) {
              int reminderIndex = dayReminders.indexOf(reminder);
              return ListTile(
                title: Text(reminder['activity']!),
                subtitle: Text(reminder['time']!),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    onDelete(day, reminderIndex);
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RemindersListPage(reminders: reminders, onDelete: onDelete)),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
