import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fitlab_mobile2/providers/user_provider.dart';
import 'package:fitlab_mobile2/config/api_constants.dart';
import 'package:fitlab_mobile2/utils/plan_permissions.dart'; 
import 'package:fitlab_mobile2/screens/chat_central_screen.dart';
import 'package:fitlab_mobile2/screens/coach_ai_training_screen.dart';
import 'package:fitlab_mobile2/screens/coach_team_management_screen.dart';
import 'package:fitlab_mobile2/screens/create_challenge_screen.dart';
import 'package:fitlab_mobile2/screens/prescribe_training_screen.dart';
import 'package:fitlab_mobile2/screens/student_management_screen.dart';
import 'package:fitlab_mobile2/screens/students_ranking_screen.dart';

class CoachDashboard extends StatefulWidget {
  const CoachDashboard({super.key});

  @override
  State<CoachDashboard> createState() => _CoachDashboardState();
}

class _CoachDashboardState extends State<CoachDashboard> {
  final double _ratingCoach = 5.0;
  int _alunosAtivos = 0;
  List<dynamic> _solicitacoesPendentes = [];
  List<dynamic> _topAlunos = []; 
  List<dynamic> _meusDesafios = []; 
  bool _isLoading = false;

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
    _carregarDadosDashboard();
  }

  Future<void> _carregarDadosDashboard() async {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idCoach = userProvider.usuarioLogado?.id;
    if (idCoach == null) return;

    setState(() => _isLoading = true);

    try {
      final urlPendentes = Uri.parse(
        '${ApiConstants.baseUrl}/mentorias/treinador/$idCoach/pendentes',
      );
      final urlContagem = Uri.parse(
        '${ApiConstants.baseUrl}/mentorias/treinador/$idCoach/alunos/count',
      );
      final urlRanking = Uri.parse(
        '${ApiConstants.baseUrl}/gamificacao/treinador/$idCoach/ranking-alunos/top10',
      );
      final urlDesafios = Uri.parse(
        '${ApiConstants.baseUrl}/desafios/treinador/$idCoach',
      );

      // 👇 INJETANDO O TOKEN NAS 4 REQUISIÇÕES SIMULTÂNEAS 👇
      final headers = _getAuthHeaders();
      final responses = await Future.wait([
        http.get(urlPendentes, headers: headers),
        http.get(urlContagem, headers: headers),
        http.get(urlRanking, headers: headers),
        http.get(urlDesafios, headers: headers),
      ]);

      if (!mounted) return;
      setState(() {
        if (responses[0].statusCode == 200) {
          _solicitacoesPendentes = json.decode(utf8.decode(responses[0].bodyBytes));
        }

        if (responses[1].statusCode == 200) {
          _alunosAtivos = int.tryParse(responses[1].body) ?? 0;
        }

        if (responses[2].statusCode == 200) {
          _topAlunos = json.decode(utf8.decode(responses[2].bodyBytes));
        }

        if (responses[3].statusCode == 200) {
          _meusDesafios = json.decode(utf8.decode(responses[3].bodyBytes));
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar dashboard do coach: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _responderSolicitacao(int idMentoria, bool aceitar) async {
    final url = aceitar
        ? Uri.parse('${ApiConstants.baseUrl}/mentorias/$idMentoria/aceitar')
        : Uri.parse('${ApiConstants.baseUrl}/mentorias/$idMentoria/recusar');

    try {
      // 👇 INJETANDO O TOKEN NO PUT E NO DELETE 👇
      final response = aceitar 
          ? await http.put(url, headers: _getAuthHeaders()) 
          : await http.delete(url, headers: _getAuthHeaders());

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                aceitar
                    ? "Atleta adicionado à sua equipe!"
                    : "Solicitação recusada.",
              ),
              backgroundColor: aceitar
                  ? const Color(0xFF06B6D4)
                  : Colors.redAccent,
            ),
          );
        }

        if (mounted) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          await userProvider.recarregarUsuario();
        }

        if (mounted) _carregarDadosDashboard();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erro ao processar solicitação: ${response.body}"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erro na requisição: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final planoObj = userProvider.usuarioLogado?.plano;
    final String nomePlanoAtual = planoObj?['nome'] ?? "START";
    final permissions = PlanPermissions(nomePlanoAtual);
    final String statusCref =
        userProvider.usuarioLogado?.statusCref ?? "SEM_CREF";

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF06B6D4),
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: () async {
        await Provider.of<UserProvider>(
          context,
          listen: false,
        ).recarregarUsuario();
        await _carregarDadosDashboard();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24, top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, // Alinha pelo topo caso quebre linha
              children: [
                Expanded( 
                  child: Wrap( 
                    spacing: 8, 
                    runSpacing: 8, 
                    children: [
                      _buildCoachPlanBadge(nomePlanoAtual.toUpperCase()),
                      _buildCrefBadge(statusCref),
                    ],
                  ),
                ),
                const SizedBox(width: 8), // Margem de segurança para a nota não colar
                _buildRatingBadge(_ratingCoach),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _StatMiniCard(
                  label: "ALUNOS ATIVOS",
                  value:
                      "$_alunosAtivos/${permissions.limitStudents}",
                  color: Colors.greenAccent,
                  icon: Icons.people_alt_rounded,
                ),
                const SizedBox(width: 12),
                _StatMiniCard(
                  label: "SALDO A RECEBER",
                  value:
                      "R\$ ${(userProvider.usuarioLogado?.saldoFinanceiro ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}",
                  color: Colors.amber,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_solicitacoesPendentes.isNotEmpty) ...[
              const _DashboardSectionHeader(
                title: "NOVOS ATLETAS ELITE",
                subtitle: "Solicitações de mentoria pendentes",
              ),
              const SizedBox(height: 12),
              ..._solicitacoesPendentes.map(
                (aluno) => _buildMentorshipRequestCard(aluno),
              ),
              const SizedBox(height: 24),
            ],

            const Text(
              "AÇÕES DE LABORATÓRIO",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildQuickActionsGrid(context, permissions),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _DashboardSectionHeader(
                  title: "RANKING DE ALUNOS",
                  subtitle: "Top 10 por volume de treinos",
                ),
                _buildBadgeCounter("MÊS ATUAL", Icons.calendar_today_rounded),
              ],
            ),
            const SizedBox(height: 12),
            _buildRankingList(),

            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentsRankingScreen(),
                    ),
                  );
                },
                child: const Text(
                  "VER RANKING COMPLETO",
                  style: TextStyle(
                    color: Color(0xFF06B6D4),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const _DashboardSectionHeader(
              title: "MEUS DESAFIOS ATIVOS",
              subtitle: "Gestão de engajamento",
            ),
            const SizedBox(height: 12),
            _buildDesafiosList(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingList() {
    if (_topAlunos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              color: Colors.white24,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              "Nenhum aluno com treinos registrados ainda.",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topAlunos.length > 10 ? 10 : _topAlunos.length, 
        separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
        itemBuilder: (context, index) {
          final aluno = _topAlunos[index];
          Color positionColor = Colors.white54;
          if (index == 0) positionColor = Colors.amber;
          if (index == 1) positionColor = Colors.grey[400]!;
          if (index == 2) positionColor = Colors.brown[300]!;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: positionColor.withValues(alpha: 0.2),
              child: Text(
                "#${index + 1}",
                style: TextStyle(color: positionColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            title: Text(
              aluno['nome'] ?? 'Atleta',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${aluno['totalTreinos'] ?? 0}",
                  style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Text(
                  "treinos",
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesafiosList() {
    if (_meusDesafios.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
        ),
        child: const Column(
          children: [
            Icon(Icons.flag_outlined, color: Colors.white24, size: 32),
            SizedBox(height: 12),
            Text(
              "Nenhum desafio ativo no momento",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _meusDesafios.length,
      itemBuilder: (context, index) {
        final desafio = _meusDesafios[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.2)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A1A),
                const Color(0xFF06B6D4).withValues(alpha: 0.05),
              ],
            )
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.5))
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desafio['nome'] ?? 'Desafio',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desafio['descricao'] ?? 'Descrição do desafio',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.group, color: Color(0xFF06B6D4), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "${desafio['qtdInscritos'] ?? 0} atletas",
                          style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoachPlanBadge(String planName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF06B6D4),
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            planName,
            style: const TextStyle(
              color: Color(0xFF06B6D4),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(8),
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
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentorshipRequestCard(Map<String, dynamic> aluno) {
    final int idVinculo = aluno['id'] ?? aluno['idMentoria'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            child: Text(
              aluno['avatar'] ?? "🏃‍♂️",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aluno['nome'] ?? "Atleta Elite",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  aluno['objetivo'] != null
                      ? "Objetivo: ${aluno['objetivo']}"
                      : "Solicitação de mentoria",
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38),
            onPressed: () => _responderSolicitacao(idVinculo, false),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF06B6D4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.check, color: Colors.black, size: 20),
              onPressed: () => _responderSolicitacao(idVinculo, true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(
    BuildContext context,
    PlanPermissions permissions,
  ) {
    return GridView.count(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: [
        _buildActionCard(Icons.groups_rounded, "Alunos e Turmas", () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StudentManagementScreen(),
            ),
          );
        }),
        _buildActionCard(Icons.fitness_center_rounded, "Prescrever Treino", () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrescribeTrainingScreen(),
            ),
          );
        }),
        _buildActionCard(Icons.forum_rounded, "Central de Chat", () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatCentralScreen()),
          );
        }),
        _buildActionCard(
          Icons.emoji_events_rounded,
          "Criar Desafio",
          permissions.canCreateChallenge
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateChallengeScreen(),
                    ),
                  );
                }
              : null,
          isLocked: !permissions.canCreateChallenge,
        ),
        _buildActionCard(
          Icons.psychology_rounded,
          "IA de Treino",
          permissions.canUseAI
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CoachAITrainingScreen(),
                    ),
                  );
                }
              : null,
          isLocked: !permissions.canUseAI,
        ),
        if (permissions.canManageTeam)
          _buildActionCard(
            Icons.manage_accounts_rounded,
            "Gestão de Equipe",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CoachTeamManagementScreen(),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool isLocked = false,
  }) {
    return Opacity(
      opacity: isLocked ? 0.4 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLocked ? Colors.white10 : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isLocked ? Colors.grey : const Color(0xFF06B6D4),
                size: 18,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isLocked)
                const Icon(Icons.lock_outline, size: 12, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCounter(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF06B6D4), size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF06B6D4),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color.withValues(alpha: 0.5), size: 16),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _DashboardSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF06B6D4),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}