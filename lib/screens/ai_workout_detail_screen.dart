import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/session_api.dart';
import '../config/api_constants.dart';
import 'subscription_screen.dart';
import 'plan_sessions_screen.dart';

class AIWorkoutDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const AIWorkoutDetailScreen({super.key, required this.data});

  Future<void> _enviarAjusteParaAPI(
    BuildContext context,
    String promptAjuste,
  ) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final usuario = userProvider.usuarioLogado;
    final token = userProvider.token;

    final idTreino = data['id'];

    if (usuario == null) return;

    if (idTreino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Erro: ID da fórmula não encontrado. Acesse pelo Histórico para ajustar.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: Color(0xFF06B6D4)),
                SizedBox(height: 24),
                Text(
                  "RECALCULANDO FÓRMULA...",
                  style: TextStyle(
                    color: Color(0xFF06B6D4),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "O Cérebro FitLab está aplicando seu ajuste biológico e recalculando o volume.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );

    final url = Uri.parse('${ApiConstants.baseUrl}/ia/ajustar-treino');
    final payload = {
      "usuario_id": usuario.id,
      "treino_id": idTreino,
      "ajuste_solicitado": promptAjuste,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );

      if (context.mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final treinoAjustado = json.decode(utf8.decode(response.bodyBytes));

        treinoAjustado['id'] = idTreino;
        treinoAjustado['inputs_usuario'] = data['inputs_usuario'];

        if (context.mounted) {
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AIWorkoutDetailScreen(data: treinoAjustado),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Fórmula ajustada com sucesso!"),
              backgroundColor: Color(0xFF06B6D4),
            ),
          );
        }
      } else {
        if (response.body.contains('LIMITE_EXCEDIDO')) {
          if (context.mounted) _mostrarPaywallAjuste(context);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Falha ao ajustar o treino. Tente novamente."),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao solicitar ajuste: $e");
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("O Cérebro FitLab está offline no momento."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _abrirAjusteOuSessoes(BuildContext context) async {
    final id = data['id'];
    if (id == null) {
      _abrirDialogoAjuste(context);
      return;
    }
    final api = SessionApi(token: context.read<UserProvider>().token);
    try {
      final plano = await api.get('/planos-ia/$id');
      if (!context.mounted) return;
      if (plano['dataAtivacao'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Para ajustar um plano ativado, abra uma sessão concluída e selecione Reavaliar próximas sessões.',
            ),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlanSessionsScreen()),
        );
      } else {
        _abrirDialogoAjuste(context);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível verificar o plano. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      api.close();
    }
  }

  void _abrirDialogoAjuste(BuildContext context) {
    final TextEditingController ajusteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high, color: Color(0xFF06B6D4)),
            SizedBox(width: 8),
            Text(
              "AJUSTE BIOMÉTRICO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Descreva o que deseja mudar na fórmula.\nEx: 'Tenho dor no joelho, reduza o impacto' ou 'Remova os treinos de sexta'.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ajusteController,
              maxLength: 250,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Digite sua solicitação...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF06B6D4),
                    width: 1,
                  ),
                ),
                counterStyle: const TextStyle(
                  color: Color(0xFF06B6D4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CANCELAR",
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (ajusteController.text.trim().isEmpty) return;

              Navigator.pop(context);
              _enviarAjusteParaAPI(context, ajusteController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "SINTETIZAR",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarPaywallAjuste(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.redAccent, size: 56),
            const SizedBox(height: 24),
            const Text(
              "LIMITE ATINGIDO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Você esgotou os ajustes biológicos do seu plano atual (Pro: 6 | Elite: 20).\n\nFaça o upgrade para liberar edições ilimitadas e refinar sua performance ao máximo.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "CONHECER PLANOS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? inputsUsuario = data['inputs_usuario'];
    final String meta =
        inputsUsuario?['meta']?.toString().toUpperCase() ?? "PERFORMANCE";
    final String tituloIA = data['titulo'] ?? "Protocolo de Treinamento";
    final String focoIA =
        data['foco'] ??
        "Plano salvo. Consulte a prescrição e as sessões disponíveis.";

    final rawDias = data['dias'];
    final List<dynamic> dias = rawDias is List
        ? rawDias.whereType<Map>().toList()
        : [];
    final rawAquecimento = data['aquecimento'];
    final List<dynamic> aquecimento = rawAquecimento is List
        ? rawAquecimento
        : [];

    double distanciaTotal = 0;
    for (var dia in dias) {
      distanciaTotal +=
          double.tryParse(dia['distancia_km']?.toString() ?? "0") ?? 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "RELATÓRIO DE SÍNTESE",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(meta, tituloIA, focoIA),
            if (data['limitacao_estrutura'] != null) ...[
              Text(data['limitacao_estrutura']),
              if (data['conteudo_original'] is String)
                SelectableText(data['conteudo_original']),
            ],
            const SizedBox(height: 16),
            if (data['id'] is int)
              PlanActivationCard(planoId: data['id'])
            else
              const Text(
                'Plano sem identificador persistido. Consulte o histórico antes de ativar.',
              ),
            const SizedBox(height: 32),
            Row(
              children: [
                _buildMetricBox(
                  "VOL. TOTAL",
                  "${distanciaTotal.toStringAsFixed(1)} km",
                  Icons.straighten,
                ),
                const SizedBox(width: 12),
                _buildMetricBox(
                  "DIAS NO PLANO",
                  "${dias.length}",
                  Icons.event_note,
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "PROTOCOLO DE AQUECIMENTO",
              style: TextStyle(
                color: Color(0xFF06B6D4),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: aquecimento
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.science,
                            color: Color(0xFF06B6D4),
                            size: 14,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              w.toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 32),
            const Text(
              "CRONOGRAMA DE EXECUÇÃO",
              style: TextStyle(
                color: Color(0xFF06B6D4),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: dias
                  .map(
                    (dia) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF06B6D4).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dia['dia']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                dia['distancia_km'] == null
                                    ? "Distância não prescrita"
                                    : "${dia['distancia_km']} km",
                                style: const TextStyle(
                                  color: Color(0xFF06B6D4),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            dia['descricao']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 40),
            _buildAdjustButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String meta, String titulo, String foco) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meta,
          style: const TextStyle(
            color: Color(0xFF06B6D4),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          foco,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF06B6D4), size: 18),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.5)),
        color: const Color(0xFF06B6D4).withOpacity(0.1),
      ),
      child: ElevatedButton.icon(
        onPressed: () => _abrirAjusteOuSessoes(context),
        icon: const Icon(Icons.auto_fix_high, color: Color(0xFF06B6D4)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        label: const Text(
          "SOLICITAR AJUSTE DA IA",
          style: TextStyle(
            color: Color(0xFF06B6D4),
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
