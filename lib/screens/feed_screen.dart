import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/feed_card.dart';
import '../widgets/suggest_user_card.dart';
import '../widgets/trending_challenge_card.dart';
import '../widgets/streak_meter.dart';
import '../widgets/profile_level_card.dart';
import '../models/feed_timeline.dart';
import '../services/session_api.dart';

class FeedScreen extends StatefulWidget {
  final bool active;
  final SessionApi? api;
  final Duration autoRefreshInterval;
  const FeedScreen({
    super.key,
    this.active = true,
    this.api,
    this.autoRefreshInterval = const Duration(seconds: 30),
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  List<dynamic> _sugestoesDb = [];
  bool _isLoadingSugestoes = true;
  List<dynamic> _desafiosDb = [];
  bool _isLoadingDesafios = true;
  Map<String, dynamic>? _meuNivelData;
  bool _isLoadingNivel = true;
  Map<String, dynamic>? _experimentoAtivo;
  bool _isLoadingExperimento = true;

  final _scrollController = ScrollController();
  final _socialStartKey = GlobalKey();
  UserProvider? _provider;
  SessionApi? _api;
  bool _ownsApi = false;
  FeedTimeline? _timeline;
  Timer? _timer;
  Future<void>? _refreshingAll;
  int? _userId;
  String? _token;
  int _revision = -1;
  int _accountVersion = 0;
  bool _identityInitialized = false;
  bool _foreground = true;
  bool _routeVisible = true;

  List<Map<String, dynamic>> get _feedDb => _timeline?.posts ?? [];
  bool get _isLoadingFeed => _timeline?.loading ?? false;
  bool get _isLoadingMore => _timeline?.loadingMore ?? false;
  bool get _hasMore => _timeline?.hasMore ?? false;
  bool get _canRefresh =>
      mounted &&
      widget.active &&
      _foreground &&
      _routeVisible &&
      _api != null &&
      _userId != null &&
      (_token?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (_routeVisible != routeVisible) {
      _routeVisible = routeVisible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncTimer();
        if (_canRefresh) _refreshAll();
      });
    }
    final provider = context.read<UserProvider>();
    if (_provider != provider) {
      _provider?.removeListener(_onUserChanged);
      _provider = provider;
      _provider!.addListener(_onUserChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onUserChanged();
      });
    }
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      _identityInitialized = false;
      _onUserChanged();
    } else if (!oldWidget.active && widget.active) {
      _refreshAll();
    }
    _syncTimer();
  }

  void _onUserChanged() {
    if (!mounted) return;
    final id = _provider?.usuarioLogado?.id;
    final token = _provider?.token;
    final revision = _provider?.feedRevision ?? 0;
    final identityChanged =
        !_identityInitialized || id != _userId || token != _token;
    if (!identityChanged && revision == _revision) return;
    _revision = revision;
    if (identityChanged) {
      _identityInitialized = true;
      ++_accountVersion;
      _refreshingAll = null;
      _timeline?.removeListener(_onTimelineChanged);
      _timeline?.dispose();
      if (_ownsApi) _api?.close();
      _userId = id;
      _token = token;
      _api = id != null && token != null
          ? widget.api ?? SessionApi(token: token)
          : null;
      _ownsApi = _api != null && widget.api == null;
      _timeline = _api == null ? null : FeedTimeline(api: _api!, userId: id!);
      _timeline?.addListener(_onTimelineChanged);
      setState(() {
        _sugestoesDb = [];
        _desafiosDb = [];
        _meuNivelData = null;
        _experimentoAtivo = null;
        _isLoadingNivel = _isLoadingSugestoes = _isLoadingDesafios =
            _isLoadingExperimento = _api != null;
      });
    }
    if (_canRefresh) _refreshAll();
    _syncTimer();
  }

  void _onTimelineChanged() {
    if (mounted) setState(() {});
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!_canRefresh || widget.autoRefreshInterval <= Duration.zero) return;
    _timer = Timer.periodic(widget.autoRefreshInterval, (_) {
      if (!_canRefresh || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      // Do not reset pagination or jump the content while the user is reading older posts.
      if (!_atTimelineStart) return;
      if (_refreshingAll != null || _isLoadingMore || _isLoadingFeed) return;
      _timeline?.refresh();
    });
  }

  bool get _atTimelineStart {
    final box = _socialStartKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final headerTop = box.localToGlobal(Offset.zero).dy;
      return headerTop >=
          MediaQuery.paddingOf(context).top + kToolbarHeight - 16;
    }
    return !_scrollController.hasClients || _scrollController.offset <= 16;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    final returning = resumed && !_foreground;
    _foreground = resumed;
    _syncTimer();
    if (returning && _canRefresh) _refreshAll();
  }

  Future<void> _refreshAll() {
    if (!_canRefresh) return Future.value();
    if (_refreshingAll != null) {
      _timeline?.refresh();
      return _refreshingAll!;
    }
    final version = _accountVersion;
    final future = Future.wait([
      _timeline!.refresh(),
      _fetchSugestoes(),
      _fetchDesafios(),
      _fetchMeuNivel(),
      _fetchExperimentoAtivo(),
    ]).then<void>((_) {});
    _refreshingAll = future.whenComplete(() {
      if (version == _accountVersion) _refreshingAll = null;
    });
    return _refreshingAll!;
  }

  Future<void> _section(
    String path,
    void Function(dynamic) apply,
    VoidCallback finish,
  ) async {
    final api = _api;
    final version = _accountVersion;
    if (api == null) return;
    try {
      final data = await api.get(path);
      if (mounted && version == _accountVersion) {
        setState(() {
          apply(data);
          finish();
        });
      }
    } catch (_) {
      if (mounted && version == _accountVersion) setState(finish);
    }
  }

  Future<void> _fetchExperimentoAtivo() => _section(
    '/usuarios/$_userId/experimentos/ativo',
    (data) => _experimentoAtivo = data is Map
        ? Map<String, dynamic>.from(data)
        : null,
    () => _isLoadingExperimento = false,
  );
  Future<void> _fetchMeuNivel() => _section(
    '/usuarios/$_userId/perfil',
    (data) => _meuNivelData = data is Map && data['nivel'] is Map
        ? Map<String, dynamic>.from(data['nivel'])
        : null,
    () => _isLoadingNivel = false,
  );
  Future<void> _fetchSugestoes() => _section(
    '/feed/sugestoes/$_userId',
    (data) => _sugestoesDb = List<dynamic>.from(data),
    () => _isLoadingSugestoes = false,
  );
  Future<void> _fetchDesafios() => _section(
    '/feed/desafios-em-alta',
    (data) => _desafiosDb = List<dynamic>.from(data),
    () => _isLoadingDesafios = false,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _provider?.removeListener(_onUserChanged);
    _timeline?.removeListener(_onTimelineChanged);
    _timeline?.dispose();
    if (_ownsApi) _api?.close();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: RefreshIndicator(
        color: const Color(0xFF06B6D4),
        backgroundColor: const Color(0xFF1A1A1A),
        onRefresh: _refreshAll,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF1A1A1A),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                collapseMode: CollapseMode.parallax,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: const Text(
                  "FEED FITLAB",
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
                    opacity: 0.3,
                    child: Icon(
                      Icons.people_alt_outlined,
                      size: 100,
                      color: Colors.white10,
                    ),
                  ),
                ),
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: StreakMeter(),
                ),
              ],
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 20, left: 24, right: 24),
                child: Text(
                  "Acompanhe outros usuários do FitLab",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: _isLoadingNivel
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF06B6D4),
                        ),
                      )
                    : _meuNivelData == null
                    ? const Text(
                        'Não foi possível carregar seu nível.',
                        style: TextStyle(color: Colors.white54),
                      )
                    : ProfileLevelCard(nivelData: _meuNivelData!),
              ),
            ),

            // SEÇÃO DO EXPERIMENTO ATIVO CONECTADA AO BANCO 
            SliverToBoxAdapter(
              child: _isLoadingExperimento
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF06B6D4),
                        ),
                      ),
                    )
                  : (_experimentoAtivo == null)
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text(
                        "Nenhum experimento ativo. Vá ao laboratório!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        // Extraindo dados da API
                        final String volumeMetaStr =
                            _experimentoAtivo!['volume']?.toString() ?? "0";
                        final double progressoReal =
                            (_experimentoAtivo!['progresso'] ?? 0.0).toDouble();

                        double kmMetaNumerico =
                            double.tryParse(
                              volumeMetaStr.replaceAll(RegExp(r'[^0-9.]'), ''),
                            ) ??
                            0.0;
                        double kmAtual = kmMetaNumerico * progressoReal;

                        // Lógica do DataFim para os dias restantes
                        String diasRestantesFormatados = "0";
                        if (_experimentoAtivo!['dataFim'] != null) {
                          try {
                            DateTime dataFim = DateTime.parse(
                              _experimentoAtivo!['dataFim'],
                            );
                            int dias = dataFim
                                .difference(DateTime.now())
                                .inDays;
                            diasRestantesFormatados = (dias > 0 ? dias : 0)
                                .toString();
                          } catch (e) {
                            diasRestantesFormatados =
                                _experimentoAtivo!['frequencia']?.toString() ??
                                "0";
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF06B6D4).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "ANDAMENTO DO EXPERIMENTO",
                                    style: TextStyle(
                                      color: Color(0xFF06B6D4),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    "$diasRestantesFormatados dias restantes",
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${kmAtual.toStringAsFixed(1)}km",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      "Meta: ${volumeMetaStr}km",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Stack(
                                children: [
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: progressoReal.clamp(0.0, 1.0),
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF06B6D4),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF06B6D4,
                                            ).withOpacity(0.3),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // Seção QUEM SEGUIR DINÂMICA
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "QUEM SEGUIR",
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: _isLoadingSugestoes
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF06B6D4),
                            ),
                          )
                        : _sugestoesDb.isEmpty
                        ? const Center(
                            child: Text(
                              "Nenhuma sugestão no momento.",
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _sugestoesDb.length,
                            itemBuilder: (context, index) {
                              final usuarioApi = _sugestoesDb[index];
                              return SuggestUserCard(usuario: usuarioApi);
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "DESAFIOS EM ALTA",
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: _isLoadingDesafios
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF06B6D4),
                            ),
                          )
                        : _desafiosDb.isEmpty
                        ? const Center(
                            child: Text(
                              "Nenhum desafio no momento.",
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _desafiosDb.length,
                            itemBuilder: (context, index) {
                              final desafio = _desafiosDb[index];
                              return TrendingChallengeCard(desafio: desafio);
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildTerritoryMapCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            SliverToBoxAdapter(
              child: Padding(
                key: _socialStartKey,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Text(
                  "SOCIAL",
                  style: TextStyle(
                    color: Color(0xFF06B6D4),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),

            if (_timeline?.error != null && _feedDb.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Text(
                    _timeline!.error!,
                    style: const TextStyle(color: Color(0xFFFBBF24)),
                  ),
                ),
              ),
            // Feed Social Dinâmico
            if (_isLoadingFeed)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                  ),
                ),
              )
            else if (_feedDb.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Text(
                      _timeline?.error ??
                          "Nenhuma atividade recente. Seja o primeiro!",
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final postagem = _feedDb[index];
                    return FeedCard(
                      key: ValueKey(postagem['id']),
                      post: postagem,
                    );
                  }, childCount: _feedDb.length),
                ),
              ),

            if (!_isLoadingFeed && _feedDb.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator(
                            color: Color(0xFF06B6D4),
                          )
                        : _hasMore
                        ? OutlinedButton(
                            onPressed: () => _timeline?.loadMore(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF06B6D4),
                              side: const BorderSide(color: Color(0xFF06B6D4)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text("CARREGAR MAIS POSTS"),
                          )
                        : const Text(
                            "Você chegou ao fim do FitFeed! 🏁",
                            style: TextStyle(color: Colors.white38),
                          ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildTerritoryMapCard() {
    return Container();
  }
}
