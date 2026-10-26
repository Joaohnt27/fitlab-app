import 'dart:convert';
import 'dart:math';
import '../services/session_api.dart';

class ActivitySaveAttempt {
  final Map<String, dynamic> _payload;
  bool saving = false;
  Map<String, dynamic>? result;
  String? error;
  ActivitySaveAttempt(Map<String, dynamic> payload)
    : _payload = jsonDecode(jsonEncode({...payload, 'tentativaId': _uuid()}));

  static String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<Map<String, dynamic>?> save(SessionApi api) async {
    if (saving) return null;
    if (result != null) return result;
    saving = true;
    error = null;
    try {
      final response = await api.post('/atividades/registrar', _payload);
      if (response is! Map ||
          response['xpGanhos'] is! int ||
          response['distanciaOficial'] is! num) {
        throw const FormatException('Resposta de registro incompleta.');
      }
      result = Map<String, dynamic>.from(response);
      return result;
    } catch (_) {
      error =
          'Não foi possível confirmar o salvamento. Seus dados continuam nesta tela. Tente novamente.';
      return null;
    } finally {
      saving = false;
    }
  }
}
