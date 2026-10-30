import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String keyCustomBaseUrl = 'custom_base_url';

  // Environment Presets
  static const String productionUrl =
      'https://fraudguard-backend-g3e4.onrender.com/api/v1';

  static const String localHostUrl = 'http://localhost:8081/api/v1';

  // Default Base URL points to live Render production backend
  static String get defaultBaseUrl => productionUrl;

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keyCustomBaseUrl);
    // Purge outdated, stale, localhost or unreachable IPs so the app always uses live backend
    if (saved != null &&
        (saved.contains('192.168.1.10') ||
         saved.contains('10.190.54.128') ||
         saved.contains('10.18.57.128') ||
         saved.contains('localhost') ||
         saved.contains('127.0.0.1'))) {
      await prefs.remove(keyCustomBaseUrl);
      return defaultBaseUrl;
    }
    return saved ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCustomBaseUrl, url);
  }
}