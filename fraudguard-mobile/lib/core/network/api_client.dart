import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static VoidCallback? onUnauthorized;

  static const String keyAccessToken = 'accessToken';
  static const String keyRefreshToken = 'refreshToken';

  Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(keyAccessToken);

    final headers = <String, String>{};
    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final baseUrl = await ApiConstants.getBaseUrl();
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    dev.log('--> GET $uri', name: 'ApiClient');
    final headers = await _getHeaders();
    var response = await http.get(uri, headers: headers);
    dev.log('<-- ${response.statusCode} GET $uri', name: 'ApiClient');

    if (response.statusCode == 401 && !endpoint.contains('/auth/')) {
      dev.log('Received 401 Unauthorized. Attempting token refresh...', name: 'ApiClient');
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        final newHeaders = await _getHeaders();
        response = await http.get(uri, headers: newHeaders);
        dev.log('<-- ${response.statusCode} GET (Retry) $uri', name: 'ApiClient');
      }
    }

    return _processResponse(response);
  }

  Future<dynamic> post(String endpoint, {dynamic body}) async {
    final baseUrl = await ApiConstants.getBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    final bodyStr = body != null ? jsonEncode(body) : null;
    dev.log('--> POST $uri\nPayload: $bodyStr', name: 'ApiClient');

    var response = await http.post(
      uri,
      headers: headers,
      body: bodyStr,
    );
    dev.log('<-- ${response.statusCode} POST $uri', name: 'ApiClient');

    if (response.statusCode == 401 && !endpoint.contains('/auth/')) {
      dev.log('Received 401 Unauthorized. Attempting token refresh...', name: 'ApiClient');
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        final newHeaders = await _getHeaders();
        response = await http.post(
          uri,
          headers: newHeaders,
          body: bodyStr,
        );
        dev.log('<-- ${response.statusCode} POST (Retry) $uri', name: 'ApiClient');
      }
    }

    return _processResponse(response);
  }

  Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final baseUrl = await ApiConstants.getBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    final bodyStr = body != null ? jsonEncode(body) : null;
    dev.log('--> PATCH $uri\nPayload: $bodyStr', name: 'ApiClient');

    var response = await http.patch(
      uri,
      headers: headers,
      body: bodyStr,
    );
    dev.log('<-- ${response.statusCode} PATCH $uri', name: 'ApiClient');

    if (response.statusCode == 401 && !endpoint.contains('/auth/')) {
      dev.log('Received 401 Unauthorized. Attempting token refresh...', name: 'ApiClient');
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        final newHeaders = await _getHeaders();
        response = await http.patch(
          uri,
          headers: newHeaders,
          body: bodyStr,
        );
        dev.log('<-- ${response.statusCode} PATCH (Retry) $uri', name: 'ApiClient');
      }
    }

    return _processResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final baseUrl = await ApiConstants.getBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    dev.log('--> DELETE $uri', name: 'ApiClient');
    var response = await http.delete(uri, headers: headers);
    dev.log('<-- ${response.statusCode} DELETE $uri', name: 'ApiClient');

    if (response.statusCode == 401 && !endpoint.contains('/auth/')) {
      dev.log('Received 401 Unauthorized. Attempting token refresh...', name: 'ApiClient');
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        final newHeaders = await _getHeaders();
        response = await http.delete(uri, headers: newHeaders);
        dev.log('<-- ${response.statusCode} DELETE (Retry) $uri', name: 'ApiClient');
      }
    }

    return _processResponse(response);
  }

  Future<http.Response> getRaw(String endpoint) async {
    final baseUrl = await ApiConstants.getBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    dev.log('--> GET RAW $uri', name: 'ApiClient');
    var response = await http.get(uri, headers: headers);
    dev.log('<-- ${response.statusCode} GET RAW $uri', name: 'ApiClient');

    if (response.statusCode == 401 && !endpoint.contains('/auth/')) {
      dev.log('Received 401 Unauthorized. Attempting token refresh...', name: 'ApiClient');
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        final newHeaders = await _getHeaders();
        response = await http.get(uri, headers: newHeaders);
        dev.log('<-- ${response.statusCode} GET RAW (Retry) $uri', name: 'ApiClient');
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      String errorMessage = 'Request failed with status code ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('message')) {
          errorMessage = decoded['message'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<dynamic> uploadMultipart(
    String endpoint, {
    required String filePath,
    required String fileParamName,
    Map<String, String>? fields,
  }) async {
    final baseUrl = await ApiConstants.getBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(isMultipart: true);

    dev.log('--> MULTIPART POST $uri (File: $filePath)', name: 'ApiClient');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);

    if (fields != null) {
      request.fields.addAll(fields);
    }

    final mimeType = lookupMimeType(filePath) ?? 'image/jpeg';
    final parts = mimeType.split('/');
    final mediaType = MediaType(parts[0], parts[1]);

    final multipartFile = await http.MultipartFile.fromPath(
      fileParamName,
      filePath,
      contentType: mediaType,
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    dev.log('<-- ${response.statusCode} MULTIPART $uri', name: 'ApiClient');

    return _processResponse(response);
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(keyRefreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        dev.log('No refresh token stored. Auto-login refresh aborted.', name: 'ApiClient');
        onUnauthorized?.call();
        return false;
      }

      final baseUrl = await ApiConstants.getBaseUrl();
      dev.log('--> POST $baseUrl/auth/refresh', name: 'ApiClient');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      dev.log('<-- ${response.statusCode} POST /auth/refresh', name: 'ApiClient');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final newAccessToken = json['data']['accessToken'];
          if (newAccessToken != null) {
            await prefs.setString(keyAccessToken, newAccessToken);
            dev.log('Access token successfully refreshed!', name: 'ApiClient');
            return true;
          }
        }
      }
    } catch (e) {
      dev.log('Error refreshing token: $e', name: 'ApiClient', error: e);
    }
    dev.log('Token refresh failed. Triggering unauthorized callback.', name: 'ApiClient');
    onUnauthorized?.call();
    return false;
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      final decoded = jsonDecode(response.body);
      dev.log('Response Body: ${response.body}', name: 'ApiClient');
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    } else {
      String errorMessage = 'Request failed with status code ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('message')) {
          errorMessage = decoded['message'];
        }
      } catch (_) {}
      dev.log('API Exception [${response.statusCode}]: $errorMessage', name: 'ApiClient', error: errorMessage);
      throw Exception(errorMessage);
    }
  }
}
