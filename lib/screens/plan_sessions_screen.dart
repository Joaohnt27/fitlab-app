import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/session_api.dart';
import 'ai_workout_detail_screen.dart';
import 'run_screen.dart';

const _background = Color(0xFF0D0D0D);
const _surface = Color(0xFF1A1A1A);
const _accent = Color(0xFF06B6D4);

Widget _fitlabTheme(BuildContext context, Widget child) => Theme(
  data: Theme.of(context).copyWith(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: _accent,
      secondary: _accent,
      surface: _surface,
      onPrimary: Colors.black,
    ),
    textTheme: ThemeData.dark().textTheme,
    scaffoldBackgroundColor: _background,
    dividerColor: Colors.white10,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _accent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.black,
        disabledBackgroundColor: _accent.withValues(alpha: .12),
        disabledForegroundColor: Colors.white38,
        elevation: 0,
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        textStyle: ThemeData.dark().textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w800, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  ),
  child: child,
);

AppBar _appBar(
  BuildContext context,
  String title,
  VoidCallback? refresh, {
  PreferredSizeWidget? bottom,
}) => AppBar(
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  title: Text(
    title.toUpperCase(),
    maxLines: 2,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
    ),
  ),
  centerTitle: true,
  leading: IconButton(
    tooltip: 'Voltar',
    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
    onPressed: () => Navigator.maybePop(context),
  ),
  actions: [
    IconButton(
      tooltip: 'Atualizar',
      onPressed: refresh,
      icon: const Icon(Icons.refresh, color: _accent, size: 22),
    ),
  ],
  bottom: bottom,
);

Widget _panel(Widget child, {Color? accent}) => Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color:
          accent?.withValues(alpha: .2) ?? Colors.white.withValues(alpha: .06),
    ),
  ),
  child: child,
);

Widget _sectionLabel(String label, IconData icon) => Row(
  children: [
    Icon(icon, color: _accent, size: 18),
    const SizedBox(width: 10),
    Expanded(
      child: Text(
        label,
        style: const TextStyle(
          color: _accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
        ),
      ),
    ),
  ],
);

String _date(dynamic raw) {
  final value = DateTime.tryParse(raw?.toString() ?? '');
  return value == null
      ? raw?.toString() ?? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

Color _statusColor(String status) => switch (status) {
  'CONCLUIDO' || 'ATIVADO' => const Color(0xFF4ADE80),
  'DESCANSO' => Colors.white54,
  'INDISPONÍVEL' => const Color(0xFFFBBF24),
  _ => _accent,
};
Widget _status(String value) {
  final label = switch (value) {
    'CONCLUIDO' => 'CONCLUÍDA',
    'AGENDADO' => 'AGENDADA',
    _ => value,
  };
  final color = _statusColor(value);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .2)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    ),
  );
}

Widget _dataLine(IconData icon, String text, {Color color = Colors.white70}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );

Widget _notice(String message) =>
    _dataLine(Icons.info_outline, message, color: Colors.white54);
Widget _emptyState(
  IconData icon,
  String title,
  String description, {
  VoidCallback? retry,
}) => Center(
  child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _accent, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        if (retry != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ],
    ),
  ),
);

Widget _routeTile({
  required IconData icon,
  required String title,
  required String description,
  required String status,
  required VoidCallback onTap,
  String? metadata,
}) => Material(
  color: _surface,
  borderRadius: BorderRadius.circular(24),
  clipBehavior: Clip.antiAlias,
  child: InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _accent, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    _status(status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                if (metadata != null && metadata.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    metadata,
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ),
        ],
      ),
    ),
  ),
);

class PlanSessionsScreen extends StatefulWidget {
  final SessionApi? api;
  const PlanSessionsScreen({super.key, this.api});
  @override
  State<PlanSessionsScreen> createState() => _PlanSessionsScreenState();
}

class _PlanSessionsScreenState extends State<PlanSessionsScreen> {
  late SessionApi api;
  List<dynamic> sessions = [], plans = [];
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? SessionApi(token: context.read<UserProvider>().token);
    _load();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        api.get('/sessoes'),
        api.get('/planos-ia'),
      ]);
      if (mounted) {
        setState(() {
          sessions = result[0];
          plans = result[1];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Não foi possível carregar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _fitlabTheme(
    context,
    DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _background,
        appBar: _appBar(
          context,
          'Sessões e planos',
          loading ? null : _load,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: _accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withValues(alpha: .2)),
                  ),
                  labelColor: _accent,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                  tabs: const [
                    Tab(text: 'SESSÕES'),
                    Tab(text: 'PLANOS'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : error != null
            ? _emptyState(
                Icons.cloud_off_outlined,
                'Não foi possível carregar',
                error!,
                retry: _load,
              )
            : TabBarView(
                children: [
                  sessions.isEmpty
                      ? _emptyState(
                          Icons.event_note_outlined,
                          'Seu cronograma começa aqui',
                          'Confirme um plano para criar sessões datadas.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: sessions.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, index) {
                            final s = sessions[index];
                            return _routeTile(
                              icon: s['status'] == 'DESCANSO'
                                  ? Icons.nightlight_round
                                  : Icons.directions_run,
                              title: _date(s['dataPlanejada']),
                              description: s['descricao'] ?? '',
                              status: s['status'] ?? '',
                              metadata: [
                                if (s['distanciaPlanejadaKm'] != null)
                                  '${s['distanciaPlanejadaKm']} km planejados',
                                if (s['duracaoPlanejadaSegundos'] != null)
                                  '${s['duracaoPlanejadaSegundos']} s planejados',
                              ].join(' • '),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SessionDetailScreen(id: s['id']),
                                  ),
                                );
                                if (mounted) _load();
                              },
                            );
                          },
                        ),
                  plans.isEmpty
                      ? _emptyState(
                          Icons.science_outlined,
                          'Nenhum plano salvo',
                          'Seus planos ficam disponíveis aqui para revisão e confirmação.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: plans.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, index) {
                            final p = plans[index];
                            return _routeTile(
                              icon: Icons.science_outlined,
                              title: p['titulo'] ?? 'Plano',
                              description: p['dataAtivacao'] != null
                                  ? 'Ativado — consulte as sessões'
                                  : p['limitacao'] ??
                                        'Revise seu plano e escolha quando começar.',
                              status: p['dataAtivacao'] != null
                                  ? 'ATIVADO'
                                  : p['limitacao'] != null
                                  ? 'INDISPONÍVEL'
                                  : 'REVISAR',
                              onTap: () async {
                                final content = p['conteudo'];
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AIWorkoutDetailScreen(
                                      data: {
                                        if (content is Map)
                                          ...Map<String, dynamic>.from(content),
                                        'id': p['id'],
                                        'conteudo_original':
                                            p['conteudoOriginal'],
                                        'limitacao_estrutura': p['limitacao'],
                                      },
                                    ),
                                  ),
                                );
                                if (mounted) _load();
                              },
                            );
                          },
                        ),
                ],
              ),
      ),
    ),
  );
}

class PlanActivationCard extends StatefulWidget {
  final int planoId;
  final SessionApi? api;
  final DateTime? initialDate;
  const PlanActivationCard({
    super.key,
    required this.planoId,
    this.api,
    this.initialDate,
  });
  @override
  State<PlanActivationCard> createState() => _PlanActivationCardState();
}

class _PlanActivationCardState extends State<PlanActivationCard> {
  late SessionApi api;
  Map<String, dynamic>? plan;
  DateTime? start;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? SessionApi(token: context.read<UserProvider>().token);
    _load();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await api.get('/planos-ia/${widget.planoId}');
      if (mounted) {
        setState(() {
          plan = Map<String, dynamic>.from(result);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Não foi possível consultar a ativação do plano.',
        );
      }
    }
  }

  Future<void> _confirm() async {
    if (busy || start == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final date =
          '${start!.year.toString().padLeft(4, '0')}-${start!.month.toString().padLeft(2, '0')}-${start!.day.toString().padLeft(2, '0')}';
      await api.post('/planos-ia/${widget.planoId}/confirmar', {
        'dataInicio': date,
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = 'Confirmação não concluída: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _fitlabTheme(
    context,
    _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ATIVAR PLANO', Icons.event_available_outlined),
          const SizedBox(height: 16),
          if (error != null)
            _dataLine(Icons.error_outline, error!, color: Colors.redAccent),
          if (plan == null)
            TextButton(
              onPressed: _load,
              child: const Text('Consultar disponibilidade'),
            )
          else if (plan!['dataAtivacao'] != null) ...[
            _status('ATIVADO'),
            const SizedBox(height: 12),
            Text(
              'Seu plano começa em ${_date(plan!['dataInicio'])}. Consulte as sessões para acompanhar cada treino.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanSessionsScreen()),
                ),
                child: const Text('Ver sessões'),
              ),
            ),
          ] else if (plan!['ativavel'] != true)
            _notice(plan!['limitacao'] ?? 'Plano não disponível para ativação.')
          else ...[
            const Text(
              'Escolha quando começar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Revise seu plano e confirme para organizar as sessões por data.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            _notice(plan!['regraDatas'] ?? ''),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(color: _accent.withValues(alpha: .3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: busy
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              start ?? widget.initialDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) =>
                              _fitlabTheme(context, child!),
                        );
                        if (mounted && date != null)
                          setState(() => start = date);
                      },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  start == null
                      ? 'Escolher data inicial'
                      : 'Início: ${_date(start!.toIso8601String())}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy || start == null ? null : _confirm,
                child: Text(
                  busy ? 'Confirmando...' : 'Confirmar plano e criar sessões',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: busy ? null : () => Navigator.maybePop(context),
                child: const Text('Não ativar agora'),
              ),
            ),
          ],
        ],
      ),
      accent: _accent,
    ),
  );
}

class SessionDetailScreen extends StatefulWidget {
  final int id;
  final SessionApi? api;
  const SessionDetailScreen({super.key, required this.id, this.api});
  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late SessionApi api;
  Map<String, dynamic>? session;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? SessionApi(token: context.read<UserProvider>().token);
    _load();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await api.get('/sessoes/${widget.id}');
      if (mounted) {
        setState(() {
          session = Map<String, dynamic>.from(result);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Não foi possível carregar a sessão.');
      }
    }
  }

  Future<void> _start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final validated = await api.post('/sessoes/${widget.id}/iniciar');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RunScreen(
            sessaoId: widget.id,
            distanciaPlanejadaKm: (validated['distanciaPlanejadaKm'] as num?)
                ?.toDouble(),
            duracaoPlanejadaSegundos:
                validated['duracaoPlanejadaSegundos'] as int?,
          ),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => error = 'Sessão não iniciada: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _km(dynamic v) =>
      v == null ? 'Não prescrita' : '${(v as num).toStringAsFixed(2)} km';
  String _seconds(dynamic v) => v == null ? 'Não prescrita' : '$v s';
  @override
  Widget build(BuildContext context) {
    final s = session;
    final c = s?['comparacao'];
    return _fitlabTheme(
      context,
      Scaffold(
        backgroundColor: _background,
        appBar: _appBar(context, 'Sessão planejada', _load),
        body: s == null
            ? error != null
                  ? _emptyState(
                      Icons.cloud_off_outlined,
                      'Sessão indisponível',
                      error!,
                      retry: _load,
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: _accent),
                    )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  if (error != null)
                    _dataLine(
                      Icons.error_outline,
                      error!,
                      color: Colors.redAccent,
                    ),
                  const Text(
                    'SEU CRONOGRAMA',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _date(s['dataPlanejada']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _status(s['status'] ?? ''),
                  ),
                  const SizedBox(height: 24),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('PRESCRIÇÃO', Icons.directions_run),
                        const SizedBox(height: 14),
                        Text(
                          s['descricao'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        _dataLine(
                          Icons.straighten,
                          'Distância planejada: ${_km(s['distanciaPlanejadaKm'])}',
                        ),
                        _dataLine(
                          Icons.timer_outlined,
                          'Duração planejada: ${_seconds(s['duracaoPlanejadaSegundos'])}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (s['status'] == 'AGENDADO')
                    ElevatedButton.icon(
                      onPressed: busy ? null : _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(busy ? 'Aguarde...' : 'Iniciar esta sessão'),
                    ),
                  if (s['status'] == 'DESCANSO')
                    _notice('Dia de descanso — sem corrida obrigatória.'),
                  if (c != null) ...[
                    _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(
                            'PLANEJADO × REALIZADO',
                            Icons.bar_chart_rounded,
                          ),
                          const SizedBox(height: 16),
                          _dataLine(
                            Icons.straighten,
                            'Distância realizada: ${_km(c['distanciaRealizadaKm'])}',
                            color: Colors.white,
                          ),
                          _dataLine(
                            Icons.timer_outlined,
                            'Duração ativa realizada: ${c['duracaoAtivaSegundos'] ?? 'Não registrada'} s',
                            color: Colors.white,
                          ),
                          _dataLine(
                            Icons.speed,
                            'Pace realizado: ${c['paceRealizado'] ?? 'Não calculável'} /km',
                            color: Colors.white,
                          ),
                          if (c['diferencaDistanciaKm'] != null ||
                              c['diferencaDuracaoSegundos'] != null) ...[
                            const SizedBox(height: 8),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),
                            if (c['diferencaDistanciaKm'] != null)
                              _dataLine(
                                Icons.compare_arrows,
                                'Diferença (realizado − planejado): ${_km(c['diferencaDistanciaKm'])}',
                              ),
                            if (c['diferencaDuracaoSegundos'] != null)
                              _dataLine(
                                Icons.compare_arrows,
                                'Diferença de duração: ${c['diferencaDuracaoSegundos']} s',
                              ),
                          ],
                        ],
                      ),
                      accent: _accent,
                    ),
                    const SizedBox(height: 12),
                    _notice(
                      'Comparação descritiva; não representa diagnóstico ou avaliação clínica.',
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
