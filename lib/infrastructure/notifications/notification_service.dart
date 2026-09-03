import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/logger/app_logger.dart';

/// Notification service for local notifications
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _logger = AppLogger.getLogger('NotificationService');

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions on iOS
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    _initialized = true;
    _logger.info('Notification service initialized');
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    _logger.info('Notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  /// Show new release notification
  Future<void> showNewReleaseAlert({
    required String appName,
    required String version,
    String? payload,
  }) async {
    await _showNotification(
      title: 'New Release: $appName',
      body: 'Version $version is now available',
      id: _generateId('release', appName),
      payload: payload ?? appName,
    );
  }

  /// Show update available notification
  Future<void> showUpdateAlert({
    required int updateCount,
    List<String>? appNames,
    String? payload,
  }) async {
    String title;
    String body;

    if (updateCount == 1 && appNames != null && appNames.isNotEmpty) {
      title = 'Update Available';
      body = '${appNames.first} has a new version available';
    } else {
      title = '$updateCount Updates Available';
      body = appNames != null && appNames.isNotEmpty
          ? '${appNames.join(", ")} and more'
          : 'You have pending updates';
    }

    await _showNotification(
      title: title,
      body: body,
      id: _generateId('updates', 'all'),
      payload: payload ?? 'updates',
    );
  }

  /// Show sync notification
  Future<void> showSyncAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showNotification(
      title: title,
      body: body,
      id: _generateId('sync', DateTime.now().toIso8601String()),
      payload: payload ?? 'sync',
    );
  }

  /// Show download completion notification
  Future<void> showDownloadComplete({
    required String appName,
    String? filePath,
    String? payload,
  }) async {
    await _showNotification(
      title: 'Download Complete',
      body: '$appName has been downloaded successfully',
      id: _generateId('download', appName),
      payload: payload ?? filePath ?? appName,
    );
  }

  /// Show generic notification
  Future<void> _showNotification({
    required String title,
    required String body,
    required int id,
    String? payload,
  }) async {
    if (!_initialized) {
      _logger.warning('Notification service not initialized');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'omnistore_main',
      'OmniStore Notifications',
      channelDescription: 'Notifications for OmniStore',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
    _logger.info('Notification shown: $title');
  }

  /// Cancel a notification
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Generate unique notification ID
  int _generateId(String type, String identifier) {
    return type.hashCode + identifier.hashCode;
  }
}
