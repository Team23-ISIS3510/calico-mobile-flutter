import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/app_exception.dart';

class ApiClient {
  // CHANGE if needed in iOS to https://localhost:3000
  static const String _baseUrl = 'http://192.168.80.19:3000';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(
        queryParameters: query,
      );
      final response = await _client
          .get(uri, headers: const {'Content-Type': 'application/json'})
          .timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw const AppException('Request timed out. Check your connection and try again.');
    } on http.ClientException catch (e) {
      throw AppException('Connection error: ${e.message}');
    } on FormatException {
      throw const AppException('Invalid server response.');
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw const AppException('Request timed out. Check your connection and try again.');
    } on http.ClientException catch (e) {
      throw AppException('Connection error: ${e.message}');
    } on FormatException {
      throw const AppException('Invalid server response.');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }
    final message =
        (decoded as Map<String, dynamic>)['message']?.toString() ??
            'Request failed';
    throw AppException(message, statusCode: response.statusCode);
  }
}
