import 'dart:developer' as developer;
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('[FCM] Background message: ${message.messageId}', name: 'FcmService');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'fraudguard_channel',
    'FraudGuard Notifications',
    description: 'Notifications for insurance claim status updates and assignments',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _token;
  String? get token => _token;

  /// Initializes notification permissions, sets up local notifications & channels,
  /// retrieves initial token, and listens to token refresh & foreground/background messages.
  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request notification permissions (Android 13+ & iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      developer.log(
        '[FCM] Authorization status: ${settings.authorizationStatus}',
        name: 'FcmService',
      );

      // 2. Set foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Initialize FlutterLocalNotifications for Android foreground heads-up banner
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
      );

      // 4. Create high-importance Android notification channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 5. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 6. Fetch initial FCM device token
      _token = await messaging.getToken();
      developer.log('[FCM] Device Token: $_token', name: 'FcmService');

      // 7. Listen for token refresh events from Firebase
      messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        developer.log('[FCM] Token refreshed: $newToken', name: 'FcmService');
      });

      // 8. Handle foreground notifications: Display heads-up banner on screen
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log(
          '[FCM] Foreground notification: ${message.notification?.title} - ${message.notification?.body}',
          name: 'FcmService',
        );

        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title ?? 'FraudGuard Notification',
            body: notification.body ?? '',
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
              ),
            ),
          );
        }
      });
    } catch (e, stack) {
      developer.log('[FCM] Initialization error: $e', name: 'FcmService', error: e, stackTrace: stack);
    }
  }

  /// Returns the cached token or fetches it on demand.
  Future<String?> getToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token;
    }
    try {
      _token = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      developer.log('[FCM] Error fetching token: $e', name: 'FcmService');
    }
    return _token;
  }

  /// Returns the standardized platform string matching the backend pattern (ANDROID | IOS | WEB)
  static String getPlatform() {
    if (kIsWeb) return 'WEB';
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return 'ANDROID';
  }
}
