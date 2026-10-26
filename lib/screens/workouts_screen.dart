import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/subscription_screen.dart';
import 'all_challenges_screen.dart';
import '../widgets/challenge_card.dart';
import '../widgets/lab_goals_card.dart';
import '../widgets/fitlab_ai_card.dart';
import '../widgets/ai_training_result_card.dart';
import '../widgets/coach_dashboard.dart';
import '../config/api_constants.dart';
import 'chat_room_screen.dart';
import 'plan_sessions_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  bool _hasGeneratedAIWorkout = false;
  Map<String, dynamic> aiRequestData = {"goal": "", "timeframe": ""};

  Map<String, dynamic>? _experimentoAtivo;
  bool _isLoadingExperimento = true;

  Map<String, dynamic>? _mentoriaAtiva;
  bool _isLoadingMentoria = true;

  // 👇 MÉTODO AUXILIAR PARA PEGAR O HEADER COM TOKEN 👇
  Map<String, String> _getAuthHeaders() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _fetchExperimentoAtivo();
    _fetchMentoriaAtiva();
  }

  Future<void> _fetchExperimentoAtivo() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idUsuario = userProvider.usuarioLogado?.id ?? 1;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/$idUsuario/experimentos/ativo',
    );

    try {
      // 👇 INJETANDO O TOKEN NO GET 👇
      final response = await http.get(url, headers: _getAuthHeaders());
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        setState(() {
          _experimentoAtivo = json.decode(utf8.decode(response.bodyBytes));
          _isLoadingExperimento = false;
        });
      } else {
        setState(() {
          _experimentoAtivo = null;
          _isLoadingExperimento = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar experimento ativo: $e");
      setState(() => _isLoadingExperimento = false);
    }
  }

  Future<void> _fetchMentoriaAtiva() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idUsuario = userProvider.usuarioLogado?.id;

    if (idUsuario == null) return;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/mentorias/atleta/$idUsuario/ativa',
    );

    try {
      // 👇 INJETANDO O TOKEN NO GET 👇
      final response = await http.get(url, headers: _getAuthHeaders());
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        setState(() {
          _mentoriaAtiva = json.decode(utf8.decode(response.bodyBytes));
          _isLoadingMentoria = false;
        });
      } else {
        setState(() {
          _mentoriaAtiva = null;
          _isLoadingMentoria = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar mentoria ativa: $e");
      setState(() => _isLoadingMentoria = false);
    }
  }

  Future<void> _buscarMeuTreino() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idAtleta = userProvider.usuarioLogado?.id;
    if (idAtleta == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.amber)),
    );

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/treinos/atleta/$idAtleta/atual',
    );

    try {
      // 👇 INJETANDO O TOKEN NO GET 👇
      final response = await http.get(url, headers: _getAuthHeaders());
      if (context.mounted) Navigator.pop(context); 

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final treino = json.decode(utf8.decode(response.bodyBytes));

        if (treino['status'] == 'PENDENTE') {
          _mostrarModalTreinoPendente(treino);
        } else if (treino['status'] == 'ACEITO') {
          _mostrarModalTreinoAtivo(treino); 
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Você não possui treinos ativos no momento.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.amber.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Erro ao buscar treino: $e");
    }
  }

  void _mostrarModalTreinoAtivo(Map<String, dynamic> treino) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_run_rounded,
                    color: Colors.greenAccent,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  treino['titulo'] ?? "Treino Atual",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "TREINO EM ANDAMENTO",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildExperimentData("Volume / Carga", treino['volume'] ?? "N/A"),
              const SizedBox(height: 16),
              _buildExperimentData("Protocolo", treino['descricao'] ?? "N/A"),
              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context), 
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "FECHAR",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _responderTreino(treino['id'], "CONCLUIDO", ""),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "CONCLUIR TREINO",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarModalTreinoPendente(Map<String, dynamic> treino) {
    final TextEditingController motivoController = TextEditingController();
    bool isRecusando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      treino['titulo'] ?? "Novo Treino",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildExperimentData(
                    "Volume / Carga",
                    treino['volume'] ?? "N/A",
                  ),
                  const SizedBox(height: 16),
                  _buildExperimentData(
                    "Protocolo",
                    treino['descricao'] ?? "N/A",
                  ),
                  const SizedBox(height: 32),

                  if (isRecusando) ...[
                    const Text(
                      "Motivo da recusa:",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: motivoController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Ex: Estou com dor no joelho...",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.black,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () =>
                                setModalState(() => isRecusando = false),
                            child: const Text(
                              "VOLTAR",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _responderTreino(
                              treino['id'],
                              "RECUSADO",
                              motivoController.text,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "CONFIRMAR",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setModalState(() => isRecusando = true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "RECUSAR",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _responderTreino(treino['id'], "ACEITO", ""),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "ACEITAR",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _responderTreino(
    int idTreino,
    String status,
    String motivo,
  ) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/treinos/$idTreino/responder',
    );

    try {
      // 👇 INJETANDO O TOKEN NO PUT 👇
      await http.put(
        url,
        headers: _getAuthHeaders(),
        body: json.encode({"status": status, "motivo": motivo}),
      );

      if (context.mounted) {
        Navigator.pop(context); 

        String mensagem = "";
        Color corFundo = Colors.grey;

        if (status == "ACEITO") {
          mensagem = "Treino aceito! Bom trabalho!";
          corFundo = Colors.greenAccent;
        } else if (status == "CONCLUIDO") {
          mensagem = "Parabéns! Treino concluído com sucesso! 🏆";
          corFundo = const Color(0xFF06B6D4);
        } else {
          mensagem = "Treino recusado e treinador notificado.";
          corFundo = Colors.redAccent;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensagem,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            backgroundColor: corFundo,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erro ao responder: $e");
    }
  }

  Future<void> _abortarExperimento() async {
    if (_experimentoAtivo == null) return;

    final idExperimento = _experimentoAtivo!['id'];
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idUsuario = userProvider.usuarioLogado?.id ?? 1;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/$idUsuario/experimentos/$idExperimento',
    );

    setState(() => _isLoadingExperimento = true);

    try {
      // 👇 INJETANDO O TOKEN NO DELETE 👇
      final response = await http.delete(url, headers: _getAuthHeaders());
      if (response.statusCode == 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Experimento abortado com sucesso."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        _fetchExperimentoAtivo();
      }
    } catch (e) {
      debugPrint("Erro ao abortar experimento: $e");
      setState(() => _isLoadingExperimento = false);
    }
  }

  Future<List<dynamic>> _fetchDesafiosAtivos(int idUsuario) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/$idUsuario/desafios',
    );
    try {
      // 👇 INJETANDO O TOKEN NO GET 👇
      final response = await http.get(url, headers: _getAuthHeaders());
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      } else {
        throw Exception('Falha ao carregar desafios');
      }
    } catch (e) {
      debugPrint("Erro ao buscar desafios ativos: $e");
      return [];
    }
  }

  void _iniciarExperimento(String volume, String frequencia) async {
    setState(() => _isLoadingExperimento = true);

    bool sucesso = await context.read<UserProvider>().salvarExperimentoUsuario(
      context,
      volume,
      frequencia,
    );

    if (sucesso) {
      _showCustomDialog(
        "FÓRMULA PRONTA!",
        "Seu experimento de $volume configurado.",
      );
      _fetchExperimentoAtivo();
    } else {
      setState(() => _isLoadingExperimento = false);
    }
  }

  void _aoGerarTreinoIA(Map<String, dynamic> data) async {
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
                  "SINTETIZANDO FÓRMULA...",
                  style: TextStyle(
                    color: Color(0xFF06B6D4),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "O Cérebro FitLab está calculando sua biometria. Isso pode levar alguns minutos.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );

    final url = Uri.parse('${ApiConstants.baseUrl}/ia/gerar-treino');
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final usuario = userProvider.usuarioLogado;

    final payload = {
      "usuario_id": usuario?.id,
      "role": usuario?.role ?? 'Free',
      "meta": data["meta"],
      "prazo": data["prazo"],
      "peso_kg": data["peso_kg"],
      "altura_cm": data["altura_cm"],
      "nivel_experiencia": data["nivel_experiencia"],
      "contexto_adicional": data["contexto_adicional"],
      "dt_nascimento": usuario?.dtNascimento ?? "Não informada",
      "historico_app":
          "Atleta com ${usuario?.totalTreinos ?? 0} treinos no app e streak atual de ${usuario?.streak ?? 0} dias.",
    };

    try {
      // 👇 INJETANDO O TOKEN NO POST DA IA 👇
      final response = await http.post(
        url,
        headers: _getAuthHeaders(),
        body: json.encode(payload),
      );

      if (context.mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final treinoInteligente = json.decode(utf8.decode(response.bodyBytes));

        treinoInteligente['inputs_usuario'] = {
          "peso": data["peso_kg"],
          "altura": data["altura_cm"],
          "nivel": data["nivel_experiencia"],
          "meta": data["meta"],
        };

        setState(() {
          aiRequestData = treinoInteligente;
          _hasGeneratedAIWorkout = true;
        });
      } else {
        if (response.body.contains('LIMITE_EXCEDIDO')) {
          _mostrarPaywall();
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  "Falha ao gerar o treino. Tente novamente.",
                ),
                backgroundColor: Colors.redAccent.withOpacity(0.8),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Erro de conexão na IA: $e");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("O Cérebro FitLab está offline no momento."),
            backgroundColor: Colors.redAccent.withOpacity(0.8),
          ),
        );
      }
    }
  }

  void _mostrarPaywall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF06B6D4), size: 56),
            const SizedBox(height: 24),
            const Text(
              "SESSÃO EXPIRADA",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Você atingiu o limite de fórmulas da sua licença atual.\n\nFaça o upgrade para continuar gerando inteligência atlética e desbloquear todo o potencial do Cérebro FitLab.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "CONHECER PLANOS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final usuario = userProvider.usuarioLogado;

    final bool isTreinador = usuario?.role == 'Treinador';
    final bool isElite =
        usuario?.plano?['nome']?.toString().contains('Elite') ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: RefreshIndicator(
        color: const Color(0xFF06B6D4),
        backgroundColor: const Color(0xFF1A1A1A),
        onRefresh: () async {
          await _fetchMentoriaAtiva();
          await _fetchExperimentoAtivo();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(usuario?.streak ?? 0),
            const SliverToBoxAdapter(child: _PageIntroText()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isTreinador) ...[
                      const CoachDashboard(),
                    ] else ...[
                      const _SectionHeader(
                        title: "Cérebro FitLab",
                        subtitle: "Inteligência Artificial",
                      ),
                      const SizedBox(height: 16),
                      _hasGeneratedAIWorkout
                          ? AITrainingResultCard(
                              data: aiRequestData,
                              onStart: () => debugPrint("Iniciando GPS..."),
                            )
                          : FitLabAICard(onGenerate: _aoGerarTreinoIA),
                      const SizedBox(height: 32),
                      const _SectionHeader(title: "Configurar Experimento"),
                      const SizedBox(height: 16),

                      if (_isLoadingExperimento)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF06B6D4),
                          ),
                        )
                      else if (_experimentoAtivo != null)
                        _buildActiveExperimentCard()
                      else
                        LabGoalsCard(onIniciar: _iniciarExperimento),
                    ],

                    const SizedBox(height: 32),
                    if (!isTreinador) Material(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanSessionsScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: .2))),
                          child: Row(children: [
                            const Icon(Icons.event_note_outlined, color: Color(0xFF06B6D4), size: 26),
                            const SizedBox(width: 16),
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Sessões e planos', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Seu cronograma de treinos', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ])),
                            const Icon(Icons.chevron_right, color: Color(0xFF06B6D4), size: 20),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionHeader(
                      title: "Desafios Ativos",
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AllChallengesScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    FutureBuilder<List<dynamic>>(
                      future: _fetchDesafiosAtivos(usuario?.id ?? 1),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF06B6D4),
                              ),
                            ),
                          );
                        }

                        final activeChallenges = snapshot.data ?? [];

                        if (activeChallenges.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "Nenhum desafio ativo.\nExplore o Lab para aceitar novos desafios!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: activeChallenges
                              .take(3)
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: ChallengeCard(
                                    challenge: c as Map<String, dynamic>,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),

                    if (!isTreinador) ...[
                      const SizedBox(height: 32),
                      const _SectionHeader(
                        title: "Área de Testes",
                        subtitle: "Acompanhamento de Especialistas",
                      ),
                      const SizedBox(height: 16),
                      _buildMentorTestingArea(isElite),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentorTestingArea(bool isElite) {
    if (_isLoadingMentoria) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }

    if (!isElite && _mentoriaAtiva == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.05,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: double.infinity,
                  height: 160,
                  color: Colors.white,
                ),
              ),
            ),
            _buildLockOverlayElite(),
          ],
        ),
      );
    }

    if (_mentoriaAtiva == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            const Icon(Icons.person_search, color: Colors.white38, size: 40),
            const SizedBox(height: 16),
            const Text(
              "Nenhum treinador vinculado",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Você tem acesso liberado! Encontre um treinador na aba Comunidade para iniciar a sua assessoria.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final nomeTreinador =
        _mentoriaAtiva!['treinadorNome'] ??
        _mentoriaAtiva!['treinador_nome'] ??
        "Seu Treinador";

    final avatarCoach =
        _mentoriaAtiva!['treinadorAvatar'] ??
        _mentoriaAtiva!['avatar'] ??
        "👨‍🏫";

    int unreadMsgs = _mentoriaAtiva!['mensagensNaoLidas'] ?? 0;

    String diasRestantesStr = "Ativa";
    if (_mentoriaAtiva!['dataFim'] != null ||
        _mentoriaAtiva!['data_fim'] != null) {
      try {
        String dtFimRaw =
            _mentoriaAtiva!['dataFim'] ?? _mentoriaAtiva!['data_fim'];
        DateTime dataFim = DateTime.parse(dtFimRaw);
        int dias = dataFim.difference(DateTime.now()).inDays;
        diasRestantesStr = dias > 0 ? "Expira em $dias dias" : "Expira hoje";
      } catch (e) {}
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(
          0xFF1D4ED8,
        ).withOpacity(0.05), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1D4ED8).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1D4ED8).withOpacity(0.2),
                child: Text(avatarCoach, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diasRestantesStr.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nomeTreinador,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Treinador FitLab",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildActionTile(
                icon: Icons.chat_bubble_rounded,
                title: "Mensagens",
                subtitle: "Fale com o coach",
                color: const Color(0xFF06B6D4),
                unreadCount: unreadMsgs,
                onTap: () {
                  final idTreinador =
                      _mentoriaAtiva!['treinadorId'] ??
                      _mentoriaAtiva!['treinador_id'];
                  if (idTreinador != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatRoomScreen(
                          idDestinatario: idTreinador,
                          nomeDestinatario: nomeTreinador,
                          avatarDestinatario: avatarCoach,
                        ),
                      ),
                    ).then((_) {
                      _fetchMentoriaAtiva();
                    });
                  }
                },
              ),
              const SizedBox(width: 16),

              _buildActionTile(
                icon: Icons.assignment_rounded,
                title: "Meu Treino",
                subtitle: "Ver prescrição",
                color: Colors.amber,
                unreadCount: 0,
                onTap: _buscarMeuTreino, 
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "$unreadCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockOverlayElite() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.workspace_premium, color: Colors.amber, size: 36),
        const SizedBox(height: 12),
        const Text(
          "ÁREA DE TESTES FECHADA",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Exclusivo para Atletas Elite",
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
          ),
          child: const Text(
            "FAZER UPGRADE",
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveExperimentCard() {
    final volume = _experimentoAtivo!['volume'] ?? "N/A";

    String diasRestantesStr = "N/A";
    if (_experimentoAtivo!['dataFim'] != null) {
      try {
        DateTime dataFim = DateTime.parse(_experimentoAtivo!['dataFim']);
        int dias = dataFim.difference(DateTime.now()).inDays;
        diasRestantesStr = "${dias > 0 ? dias : 0} dias";
      } catch (e) {
        diasRestantesStr = _experimentoAtivo!['frequencia'] ?? "N/A";
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.science, color: Color(0xFF06B6D4)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EM ANDAMENTO",
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      "Experimento Atual",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildExperimentData("Volume Meta", "$volume km"),
              _buildExperimentData("Tempo Restante", diasRestantesStr),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _abortarExperimento,
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "ABORTAR EXPERIMENTO",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentData(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(int streak) {
    return SliverAppBar(
      expandedHeight: 120.0,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Text(
          "LABORATÓRIO",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1D4ED8), Color(0xFF0D0D0D)],
            ),
          ),
          child: const Center(
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.science_outlined,
                size: 120,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      actions: [_StreakIndicator(streak: streak)],
    );
  }

  void _showCustomDialog(String title, String content, {bool isAI = false}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAI ? Icons.psychology : Icons.science,
                color: const Color(0xFF06B6D4),
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "VAMOS NESSA!",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;
  const _SectionHeader({required this.title, this.subtitle, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF06B6D4),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text(
              "VER TODOS",
              style: TextStyle(
                color: Color(0xFF06B6D4),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _StreakIndicator extends StatelessWidget {
  final int streak;
  const _StreakIndicator({required this.streak});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: streak > 0 ? Colors.orange.withOpacity(0.2) : Colors.white10,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: streak > 0 ? Colors.orange : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                "$streak",
                style: TextStyle(
                  color: streak > 0 ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageIntroText extends StatelessWidget {
  const _PageIntroText();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 20, left: 24, right: 24),
      child: Text(
        "Seu centro de treinamento e desafios",
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }
}