import '../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  Future<List<NotificationModel>> getNotifications({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(
      '/notifications',
      queryParams: {
        'page': page.toString(),
        'size': size.toString(),
      },
    );

    if (response != null) {
      final List content = response['content'] ?? (response is List ? response : []);
      return content.map((item) => NotificationModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _api.get('/notifications/unread-count');
      if (response != null && response['unreadCount'] != null) {
        return (response['unreadCount'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  Future<NotificationModel?> markAsRead(int notificationId) async {
    try {
      final response = await _api.patch('/notifications/$notificationId/read');
      if (response != null) {
        return NotificationModel.fromJson(response);
      }
    } catch (_) {}
    return null;
  }
}
