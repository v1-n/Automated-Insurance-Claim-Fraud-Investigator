import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String keyCustomBaseUrl = 'custom_base_url';

  // Environment Presets
  static const String localHostUrl = 'http://localhost:8081/api/v1';

  // Physical Android phone connected to the same Wi-Fi as laptop
  static const String physicalDeviceUrl =
      'http://10.62.215.128:8081/api/v1';

  static const String productionUrl =
      'https://fraudguard-backend-g3e4.onrender.com/api/v1';

  // Default Base URL points to live Render backend
  static String get defaultBaseUrl => productionUrl;

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCustomBaseUrl) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCustomBaseUrl, url);
  }
}