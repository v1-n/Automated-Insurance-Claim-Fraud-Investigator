import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String keyCustomBaseUrl = 'custom_base_url';

  // Environment Presets
  // When using USB debugging, 'adb reverse tcp:8081 tcp:8081' maps localhost:8081 directly to the laptop
  static const String localHostUrl = 'http://localhost:8081/api/v1';

  // Physical Android phone connected to the same Wi-Fi as laptop (laptop current IP: 10.18.57.128)
  static const String physicalDeviceUrl =
      'http://10.18.57.128:8081/api/v1';

  static const String productionUrl =
      'https://fraudguard-backend-g3e4.onrender.com/api/v1';

  // Default Base URL points to localHostUrl (works with USB adb reverse tcp:8081 tcp:8081)
  static String get defaultBaseUrl => localHostUrl;

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keyCustomBaseUrl);
    // Purge outdated, stale or unreachable IPs
    if (saved != null && (saved.contains('192.168.1.10') || saved.contains('10.190.54.128'))) {
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