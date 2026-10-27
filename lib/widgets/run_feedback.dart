import 'package:flutter/material.dart';

const _surface = Color(0xFF1A1A1A);
const _accent = Color(0xFF06B6D4);
const _warning = Color(0xFFFBBF24);

// Feedback local ao fluxo de corrida
class RunSaveNotice extends StatelessWidget {
  final bool saving;
  final bool saved;
  final String? error;
  final VoidCallback onRetry;

  const RunSaveNotice({
    super.key,
    required this.saving,
    this.saved = false,
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final pending = saving || saved;
    final color = error == null ? _accent : _warning;
    final title = saved
        ? 'Preparando seu resumo...'
        : saving
        ? 'Salvando atividade...'
        : error != null
        ? 'Salvamento não confirmado'
        : 'Confirmação pendente';
    final message = saved
        ? 'Atividade registrada. Atualizando os dados do treino.'
        : saving
        ? 'Aguarde enquanto registramos seu treino no FitLab.'
        : error ?? 'Aguardando confirmação do salvamento.';

    return Semantics(
      liveRegion: true,
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: .28)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: pending
                        ? CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: color,
                            backgroundColor: color.withValues(alpha: .15),
                          )
                        : Icon(Icons.cloud_off_rounded, size: 22, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REGISTRO DO TREINO',
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!pending) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Tentar salvar novamente',
                    textAlign: TextAlign.center,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    elevation: 0,
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

SnackBar runFeedbackSnackBar({
  required String title,
  required String message,
  IconData icon = Icons.info_outline_rounded,
  bool warning = false,
  Duration duration = const Duration(seconds: 4),
}) {
  final color = warning ? _warning : _accent;
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: _surface,
    elevation: 0,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.all(16),
    duration: duration,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: color.withValues(alpha: .3)),
    ),
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
