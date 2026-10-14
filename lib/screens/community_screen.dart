import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../config/api_constants.dart';
import 'subscription_screen.dart';
import 'public_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int? _treinadorVinculadoId;
  int? _treinadorPendenteId;

  List<dynamic> _amigos = [];
  List<dynamic> _pendentes = [];
  bool _isLoadingAmigos = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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
    _checkMentoriaStatus();
    _carregarAmizades();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirPerfilPublico(BuildContext context, Map<String, dynamic> usuario) {
    final targetId =
        usuario['idUsuario'] ?? usuario['idAmigo'] ?? usuario['id'];

    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro ao localizar perfil do atleta."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final usuarioAlvo = {
      'id': targetId,
      'nome': usuario['nome'] ?? 'Atleta',
      'avatar': usuario['avatar'] ?? '🧪',
      'role': usuario['patente'] ?? usuario['nomePatente'] ?? 'Atleta',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(usuarioAlvo: usuarioAlvo),
      ),
    );
  }

  Future<void> _checkMentoriaStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final atletaId = userProvider.usuarioLogado?.id;
    if (atletaId == null) return;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/mentorias/atleta/$atletaId/status',
    );

    try {
      // 👇 INJETANDO TOKEN AQUI 👇
      final response = await http.get(url, headers: _getAuthHeaders());
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          if (data['status'] == 'ACEITO') {
            _treinadorVinculadoId = data['treinadorId'];
            _treinadorPendenteId = null;
          } else if (data['status'] == 'PENDENTE') {
            _treinadorPendenteId = data['treinadorId'];
            _treinadorVinculadoId = null;
          }
        });
      } else {
        setState(() {
          _treinadorVinculadoId = null;
          _treinadorPendenteId = null;
        });
      }
    } catch (e) {
      debugPrint("Erro ao verificar status da mentoria: $e");
    }
  }

  Future<void> _carregarAmizades() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idLogado = userProvider.usuarioLogado?.id;
    if (idLogado == null) return;

    setState(() => _isLoadingAmigos = true);

    try {
      // 👇 INJETANDO TOKEN AQUI 👇
      final resAmigos = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/amizades/$idLogado/lista'),
        headers: _getAuthHeaders(),
      );
      // 👇 INJETANDO TOKEN AQUI 👇
      final resPendentes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/amizades/$idLogado/pendentes'),
        headers: _getAuthHeaders(),
      );

      if (resAmigos.statusCode == 200 && resPendentes.statusCode == 200) {
        setState(() {
          _amigos = json.decode(utf8.decode(resAmigos.bodyBytes));
          _pendentes = json.decode(utf8.decode(resPendentes.bodyBytes));
          _isLoadingAmigos = false;
        });
      } else {
         setState(() => _isLoadingAmigos = false);
      }
    } catch (e) {
      debugPrint("Erro ao carregar amizades: $e");
      setState(() => _isLoadingAmigos = false);
    }
  }

  Future<void> _enviarConvite(String codigo) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idLogado = userProvider.usuarioLogado?.id;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/amizades/$idLogado/solicitar/$codigo',
    );

    try {
      // 👇 INJETANDO TOKEN NO POST AQUI 👇
      final response = await http.post(url, headers: _getAuthHeaders());
      final body = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['mensagem']),
              backgroundColor: const Color(0xFF06B6D4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['erro'] ?? "Erro ao enviar convite"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erro ao enviar convite: $e");
    }
  }

  Future<void> _usarCodigoTreinador(String codigo) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final atletaId = userProvider.usuarioLogado?.id;
    if (atletaId == null) return;

    final url = Uri.parse('${ApiConstants.baseUrl}/mentorias/vincular/codigo');
    final payload = {"atleta_id": atletaId, "codigo": codigo};

    try {
      // 👇 INJETANDO TOKEN NO POST AQUI 👇
      final response = await http.post(
        url,
        headers: _getAuthHeaders(),
        body: json.encode(payload),
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); 
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.body), 
              backgroundColor: const Color(0xFF06B6D4),
              duration: const Duration(seconds: 4),
            ),
          );
          _checkMentoriaStatus();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.body),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("O sistema está offline no momento."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _responderConvite(int idAmizade, bool aceitar) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idLogado = userProvider.usuarioLogado?.id;

    final urlAcao = aceitar
        ? '${ApiConstants.baseUrl}/amizades/$idLogado/aceitar/$idAmizade'
        : '${ApiConstants.baseUrl}/amizades/$idLogado/remover/$idAmizade';

    try {
      // 👇 INJETANDO TOKEN NO PUT/DELETE AQUI 👇
      final response = aceitar
          ? await http.put(Uri.parse(urlAcao), headers: _getAuthHeaders())
          : await http.delete(Uri.parse(urlAcao), headers: _getAuthHeaders());
          
      if (response.statusCode == 200) {
        _carregarAmizades();
      }
    } catch (e) {
      debugPrint("Erro ao responder convite: $e");
    }
  }

  Future<List<dynamic>> _fetchRankingGlobal() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/usuarios/ranking');
    try {
      // 👇 INJETANDO TOKEN AQUI 👇
      final response = await http.get(url, headers: _getAuthHeaders());
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      } else {
        throw Exception('Falha ao carregar ranking');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  Future<List<dynamic>> _fetchTreinadores() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/usuarios/treinadores');
    try {
      // 👇 INJETANDO TOKEN AQUI 👇
      final response = await http.get(url, headers: _getAuthHeaders());
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      } else {
        throw Exception('Falha ao carregar treinadores');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  Future<void> _vincularTreinador(BuildContext context, int treinadorId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final atletaId = userProvider.usuarioLogado?.id;

    if (atletaId == null) return;

    final url = Uri.parse('${ApiConstants.baseUrl}/mentorias/vincular');
    final payload = {"atleta_id": atletaId, "treinador_id": treinadorId};

    try {
      // 👇 INJETANDO TOKEN NO POST AQUI 👇
      final response = await http.post(
        url,
        headers: _getAuthHeaders(),
        body: json.encode(payload),
      );

      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (response.statusCode == 200) {
        if (context.mounted) {
          setState(() {
            _treinadorPendenteId = treinadorId;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Solicitação enviada! Aguardando aprovação do coach.",
              ),
              backgroundColor: Color(0xFF06B6D4),
            ),
          );
        }
      } else if (response.statusCode == 403 ||
          response.body.contains('PAYWALL')) {
        if (context.mounted) _mostrarPaywallMentoria(context);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.body),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("O sistema está offline no momento."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _abrirPerfilTreinador(
    BuildContext context,
    Map<String, dynamic> treinadorResumo,
  ) async {
    dynamic rawId =
        treinadorResumo['id'] ??
        treinadorResumo['idUsuario'] ??
        treinadorResumo['id_user'];
    int treinadorId = rawId != null ? (int.tryParse(rawId.toString()) ?? 0) : 0;

    if (treinadorId == 0) return;

    await _checkMentoriaStatus();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        // 👇 AQUI TEM UM GET QUE PRECISA DO TOKEN 👇
        return FutureBuilder<http.Response>(
          future: http.get(
            Uri.parse('${ApiConstants.baseUrl}/usuarios/$treinadorId/perfil'),
            headers: _getAuthHeaders(), // 👈 INJETADO AQUI
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(60.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(60.0),
                child: Center(
                  child: Text(
                    "Erro ao carregar perfil do treinador.",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            Map<String, dynamic> treinadorFull = Map<String, dynamic>.from(
              treinadorResumo,
            );

            if (snapshot.hasData && snapshot.data!.statusCode == 200) {
              final perfilData = json.decode(
                utf8.decode(snapshot.data!.bodyBytes),
              );
              treinadorFull.addAll(perfilData);
            }

            final nome = treinadorFull['nome'] ?? 'Treinador Especialista';
            final bio =
                treinadorFull['bioUsuario'] ??
                treinadorFull['bio'] ??
                treinadorFull['biografia'] ??
                'Olá! Estou aqui para otimizar a sua performance.';

            final avatar = treinadorFull['avatar'] == '🧪'
                ? '👨‍🏫'
                : (treinadorFull['avatar'] ??
                      treinadorFull['fotoPerfil'] ??
                      '👨‍🏫');

            final double rating = treinadorFull['rating'] != null
                ? (treinadorFull['rating'] as num).toDouble()
                : 5.0;
            final int qtdAlunos =
                treinadorFull['qtdAlunos'] ??
                treinadorFull['alunos'] ??
                treinadorFull['seguidores'] ??
                0;

            final String planoNome =
                treinadorFull['nomePatente'] ??
                treinadorFull['nomePlano'] ??
                treinadorFull['plano']?['nome'] ??
                'Coach Start';

            final String statusCref = treinadorFull['statusCref'] ?? 'SEM_CREF';

            String anoFiliacao = "2026";
            if (treinadorFull['dataCriacao'] != null) {
              anoFiliacao = treinadorFull['dataCriacao'].toString().split(
                '-',
              )[0];
            }

            bool isRequesting = false;

            return StatefulBuilder(
              builder: (statefulContext, setStateSheet) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white10,
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        nome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),
                      _buildCrefBadge(statusCref),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.groups,
                            color: Colors.white38,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$qtdAlunos alunos",
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.workspace_premium,
                            color: Color(0xFF06B6D4),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            planoNome,
                            style: const TextStyle(
                              color: Color(0xFF06B6D4),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "No FitLab desde $anoFiliacao",
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      isRequesting
                          ? const CircularProgressIndicator(
                              color: Color(0xFF06B6D4),
                            )
                          : _treinadorVinculadoId == treinadorId
                          ? SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "MENTORIA ATIVA",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  disabledBackgroundColor: Colors.green
                                      .withValues(alpha: 0.4),
                                  disabledForegroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            )
                          : _treinadorPendenteId == treinadorId
                          ? SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "AGUARDANDO APROVAÇÃO",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  disabledBackgroundColor: Colors.orange
                                      .withValues(alpha: 0.4),
                                  disabledForegroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            )
                          : _treinadorVinculadoId != null ||
                                _treinadorPendenteId != null
                          ? SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const Icon(
                                  Icons.block,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "VOCÊ JÁ POSSUI UM MENTOR",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  disabledBackgroundColor: Colors.white10,
                                  disabledForegroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () async {
                                  setStateSheet(() => isRequesting = true);
                                  await _vincularTreinador(
                                    statefulContext,
                                    treinadorId,
                                  );
                                  if (statefulContext.mounted) {
                                    setStateSheet(() => isRequesting = false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF06B6D4),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  "SOLICITAR MENTORIA (30 DIAS)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _mostrarPaywallMentoria(BuildContext context) {
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
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 56),
            const SizedBox(height: 24),
            const Text(
              "MENTORIA EXCLUSIVA",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Apenas Atletas do plano ELITE possuem acesso à contratação de treinadores humanos em tempo real.\n\nFaça o upgrade para destravar a mentoria e maximizar sua performance.",
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
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "CONHECER O PLANO ELITE",
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

  void _mostrarModalAdicionarAmigo() {
    final TextEditingController codigoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 32,
          left: 32,
          right: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_add_alt_1,
              color: Color(0xFF06B6D4),
              size: 48,
            ),
            const SizedBox(height: 24),
            const Text(
              "NOVO PARCEIRO DE TREINO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Digite o código de amizade do atleta.",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: codigoController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: "EX: FIT-X9K2A",
                hintStyle: const TextStyle(
                  color: Colors.white24,
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (codigoController.text.isNotEmpty) {
                    _enviarConvite(codigoController.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "ENVIAR CONVITE",
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

  void _mostrarModalCodigoTreinador() {
    final TextEditingController codigoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 32,
          left: 32,
          right: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.qr_code_scanner_rounded,
              color: Color(0xFF06B6D4),
              size: 48,
            ),
            const SizedBox(height: 24),
            const Text(
              "CÓDIGO DE ASSESSORIA",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Insira o código fornecido pelo seu treinador para liberar o acesso à assessoria dele no FitLab.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: codigoController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: "EX: FIT-COACH99",
                hintStyle: const TextStyle(
                  color: Colors.white24,
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (codigoController.text.isNotEmpty) {
                    _usarCodigoTreinador(codigoController.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "ATIVAR VÍNCULO",
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: _buildSearchBar(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: _buildMyRankCard(context),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                const TabBar(
                  indicatorColor: Color(0xFF06B6D4),
                  indicatorWeight: 3,
                  labelColor: Color(0xFF06B6D4),
                  unselectedLabelColor: Colors.white38,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  tabs: [
                    Tab(text: "GLOBAL"),
                    Tab(text: "AMIGOS"),
                    Tab(text: "TREINADORES"),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              child: TabBarView(
                children: [
                  _buildGlobalTab(),
                  _buildFriendsTab(),
                  _buildTrainersTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 120.0,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Text(
          "COMUNIDADE",
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
          child: const Opacity(
            opacity: 0.1,
            child: Icon(Icons.groups_outlined, size: 100, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: "Buscar atletas ou treinadores...",
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF06B6D4),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.white38,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = "";
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildMyRankCard(BuildContext context) {
    final user = Provider.of<UserProvider>(context).usuarioLogado;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "MINHA POSIÇÃO",
                style: TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "MEU CÓDIGO: ${user?.codigoAmizade ?? 'GERANDO...'}",
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatColumn(label: "RANK", value: "#${user?.ranking ?? '--'}"),
              _StatColumn(
                label: "TREINOS",
                value: "${user?.totalTreinos ?? 0}",
              ),
              _StatColumn(label: "FITPOINTS", value: "${user?.fitpoints ?? 0}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalTab() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchRankingGlobal(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              "Erro ao carregar o ranking.",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final atletas = snapshot.data ?? [];

        final atletasFiltrados = _searchQuery.isEmpty
            ? atletas
            : atletas.where((a) {
                final nome = (a['nome'] ?? '').toString().toLowerCase();
                return nome.contains(_searchQuery);
              }).toList();

        if (atletas.isEmpty) {
          return const Center(
            child: Text(
              "O Laboratório está vazio.",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 120,
          ),
          itemCount: atletasFiltrados.length,
          itemBuilder: (context, index) {
            final atleta = atletasFiltrados[index];
            final rankReal = atletas.indexOf(
              atleta,
            ); 

            return _RankingTile(
              index: rankReal,
              name: atleta['nome'] ?? "Atleta",
              avatar: atleta['avatar'] ?? "🧪",
              pontos: atleta['fitPoints'] ?? 0,
              patente: atleta['nomePatente'] ?? "Recruta",
              onTap: () => _abrirPerfilPublico(context, atleta),
            );
          },
        );
      },
    );
  }

  Widget _buildCrefBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'APROVADO':
        color = const Color(0xFF06B6D4);
        icon = Icons.verified;
        text = "CREF Verificado";
        break;
      case 'EM_AVALIACAO':
      case 'ENVIADO_AVALIACAO':
        color = Colors.amber;
        icon = Icons.pending_actions;
        text = "CREF em Análise";
        break;
      case 'RECUSADO':
        color = Colors.redAccent;
        icon = Icons.gpp_bad;
        text = "CREF Recusado";
        break;
      case 'SEM_CREF':
      default:
        color = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
        text = "Atua sem CREF";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoadingAmigos) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_pendentes.isNotEmpty) ...[
                const Text(
                  "CONVITES RECEBIDOS",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                ..._pendentes.map((p) => _buildPendingTile(p)),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
              ],

              const Text(
                "MEU ESQUADRÃO",
                style: TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              if (_amigos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      "Você ainda não adicionou nenhum parceiro de treino. Use o botão abaixo!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              else
                ...() {
                  final amigosFiltrados = _searchQuery.isEmpty
                      ? _amigos
                      : _amigos.where((a) {
                          final nome = (a['nome'] ?? '')
                              .toString()
                              .toLowerCase();
                          return nome.contains(_searchQuery);
                        }).toList();

                  if (amigosFiltrados.isEmpty) {
                    return [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "Nenhum parceiro encontrado na busca.",
                            style: TextStyle(color: Colors.white38),
                          ),
                        ),
                      ),
                    ];
                  }

                  return amigosFiltrados.map((a) {
                    int index = _amigos.indexOf(a); 
                    return _RankingTile(
                      index: index,
                      name: a['nome'] ?? "Amigo",
                      avatar: a['avatar'] ?? "🧪",
                      pontos: a['fitPoints'] ?? 0,
                      patente: a['patente'] ?? "Atleta",
                      onTap: () => _abrirPerfilPublico(context, a),
                    );
                  }).toList();
                }(),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 0,
            bottom: 120,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _mostrarModalAdicionarAmigo,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text(
                "ADICIONAR AMIGOS",
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF06B6D4),
                side: const BorderSide(color: Color(0xFF06B6D4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingTile(Map<String, dynamic> pendente) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            child: Text(
              pendente['avatar'] ?? "🏃‍♂️",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pendente['nome'] ?? "Atleta",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38),
            onPressed: () => _responderConvite(pendente['idAmizade'], false),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF06B6D4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.check, color: Colors.black, size: 20),
              onPressed: () => _responderConvite(pendente['idAmizade'], true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainersTab(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchTreinadores(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
          );
        }
        final treinadores = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 120,
          ),
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _mostrarModalCodigoTreinador,
                icon: const Icon(Icons.key, size: 18),
                label: const Text(
                  "USAR CÓDIGO DO TREINADOR",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF06B6D4),
                  side: const BorderSide(color: Color(0xFF06B6D4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF06B6D4),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Encontre treinadores profissionais e certificados para acelerar seus resultados",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (treinadores.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "Nenhum treinador cadastrado ainda.",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              ...() {
                final treinadoresFiltrados = _searchQuery.isEmpty
                    ? treinadores
                    : treinadores.where((t) {
                        final nome = (t['nome'] ?? '').toString().toLowerCase();
                        return nome.contains(_searchQuery);
                      }).toList();

                if (treinadoresFiltrados.isEmpty) {
                  return [
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          "Nenhum treinador encontrado na busca.",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ];
                }

                return treinadoresFiltrados.map((t) {
                  int index = treinadores.indexOf(
                    t,
                  ); 
                  final double rating = t['rating'] != null
                      ? (t['rating'] as num).toDouble()
                      : 5.0;
                  final int qtdAlunos = t['qtdAlunos'] ?? 0;
                  final String statusCref =
                      t['statusCref'] ?? t['status_cref'] ?? 'SEM_CREF';

                  return _RankingTile(
                    index: index,
                    name: t['nome'] ?? "Treinador",
                    avatar: t['avatar'] ?? "👨‍🏫",
                    isTrainer: true,
                    specialty: t['nomePatente'] ?? "Performance",
                    rating: rating,
                    students: qtdAlunos,
                    statusCref: statusCref,
                    onTap: () => _abrirPerfilTreinador(context, t),
                  );
                }).toList();
              }(),
          ],
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int index;
  final String name;
  final String? avatar;
  final int? pontos;
  final String? patente;
  final bool isTrainer;
  final String? specialty;
  final double rating;
  final int students;
  final String statusCref;
  final VoidCallback? onTap;

  const _RankingTile({
    required this.index,
    required this.name,
    this.avatar,
    this.pontos,
    this.patente,
    this.isTrainer = false,
    this.specialty,
    this.rating = 0.0,
    this.students = 0,
    this.statusCref = 'SEM_CREF',
    this.onTap,
  });

  Widget _buildMiniCrefBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'APROVADO':
        color = const Color(0xFF06B6D4);
        icon = Icons.verified;
        break;
      case 'EM_AVALIACAO':
      case 'ENVIADO_AVALIACAO':
        color = Colors.amber;
        icon = Icons.pending_actions;
        break;
      case 'RECUSADO':
      case 'SEM_CREF':
      default:
        color = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
        break;
    }
    return Icon(icon, color: color, size: 14);
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white.withValues(alpha: 0.05);
    Widget rankIcon = Text(
      "${index + 1}",
      style: const TextStyle(
        color: Color(0xFF06B6D4),
        fontWeight: FontWeight.bold,
      ),
    );
    double borderWidth = 1;

    if (!isTrainer) {
      if (index == 0) {
        borderColor = const Color(0xFFFFD700).withValues(alpha: 0.6);
        rankIcon = const Text("🥇", style: TextStyle(fontSize: 18));
        borderWidth = 2;
      } else if (index == 1) {
        borderColor = const Color(0xFFC0C0C0).withValues(alpha: 0.6);
        rankIcon = const Text("🥈", style: TextStyle(fontSize: 18));
        borderWidth = 1.5;
      } else if (index == 2) {
        borderColor = const Color(0xFFCD7F32).withValues(alpha: 0.6);
        rankIcon = const Text("🥉", style: TextStyle(fontSize: 18));
        borderWidth = 1.5;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isTrainer) SizedBox(width: 30, child: Center(child: rankIcon)),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white10,
              child: Text(
                isTrainer ? "👨‍🏫" : (avatar ?? "🧪"),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded( // 👇 1. ENVOLVE COM EXPANDED
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis, 
                          maxLines: 1, 
                        ),
                      ),
                      if (isTrainer) ...[
                        const SizedBox(width: 4),
                        _buildMiniCrefBadge(statusCref),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  isTrainer
                      ? Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium,
                              color: Color(0xFF06B6D4),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              specialty ?? "Treinador Oficial",
                              style: const TextStyle(
                                color: Color(0xFF06B6D4),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          patente ?? "Atleta FitLab",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                  if (isTrainer) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.groups,
                          color: Colors.white38,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$students alunos",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!isTrainer && pontos != null) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$pontos",
                    style: const TextStyle(
                      color: Color(0xFF06B6D4),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "FP",
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ],
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white10),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: const Color(0xFF0D0D0D), child: _tabBar); 
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}