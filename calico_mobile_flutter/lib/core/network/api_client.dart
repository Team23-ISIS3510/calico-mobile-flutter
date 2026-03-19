import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../errors/app_exception.dart';

class ApiClient {
  // Android emulator maps 10.0.2.2 → host machine localhost.
  // Change to your machine's LAN IP when testing on a real device.
  static const String _baseUrl = 'http://10.0.2.2:3000';

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded as Map<String, dynamic>;
      }

      final message =
          (decoded as Map<String, dynamic>)['message']?.toString() ??
              'Request failed';
      throw AppException(message, statusCode: response.statusCode);
    } on SocketException {
      throw const AppException(
          'No internet connection. Please check your network.');
    } on FormatException {
      throw const AppException('Invalid server response.');
    }
  }
}
