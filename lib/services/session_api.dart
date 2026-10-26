import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';

class SessionApi {
  final String? token;
  final http.Client client;
  final String baseUrl;
  SessionApi({required this.token, http.Client? client, String? baseUrl})
    : client = client ?? http.Client(),
      baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);
  Future<dynamic> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$baseUrl$path');
    final response =
        await (method == 'GET'
                ? client.get(uri, headers: headers)
                : client.post(
                    uri,
                    headers: headers,
                    body: jsonEncode(body ?? {}),
                  ))
            .timeout(const Duration(seconds: 20));
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded is Map && decoded['erro'] != null
            ? decoded['erro']
            : 'Operação não concluída (HTTP ${response.statusCode}).',
      );
    }
    return decoded;
  }

  void close() => client.close();
}
