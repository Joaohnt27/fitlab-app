import 'dart:convert';
import '../utils/request_id.dart';
import '../services/session_api.dart';

class ActivitySaveAttempt {
  final Map<String, dynamic> _payload;
  bool saving = false;
  Map<String, dynamic>? result;
  String? error;
  ActivitySaveAttempt(Map<String, dynamic> payload)
    : _payload = jsonDecode(
        jsonEncode({...payload, 'tentativaId': newRequestId()}),
      );

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
