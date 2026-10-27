import '../services/session_api.dart';
import '../utils/request_id.dart';

class AdjustmentAttempt {
  final String tentativaId;
  final String motivo;
  bool sending = false;
  Map<String, dynamic>? result;
  String? error;
  AdjustmentAttempt({required this.motivo, String? tentativaId})
    : tentativaId = tentativaId ?? newRequestId();

  Future<Map<String, dynamic>?> send(SessionApi api, int sessaoId) async {
    if (sending) return null;
    if (result != null && result!['estado'] != 'PROCESSANDO') return result;
    sending = true;
    error = null;
    try {
      final response = await api.requestAdjustment(
        '/sessoes/$sessaoId/propostas-ajuste',
        {'tentativaId': tentativaId, 'motivo': motivo},
      );
      if (response is! Map ||
          response['id'] is! int ||
          response['estado'] is! String) {
        throw const FormatException('Proposta inválida.');
      }
      result = Map<String, dynamic>.from(response);
      return result;
    } catch (e) {
      error = 'Análise não confirmada: $e';
      return null;
    } finally {
      sending = false;
    }
  }
}
