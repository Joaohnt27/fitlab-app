import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/user_provider.dart';
import '../config/api_constants.dart';
import '../utils/route_codec.dart';

class SummarySheet extends StatefulWidget {
  final List<LatLng> route;
  final List<List<LatLng>>? routeSegments;
  final double distance;
  final int duration;
  final int xp;
  final String pace;
  final String tipoAtividade;
  final VoidCallback onClose;

  const SummarySheet({
    super.key,
    required this.route,
    this.routeSegments,
    required this.distance,
    required this.duration,
    required this.xp,
    required this.pace,
    required this.tipoAtividade,
    required this.onClose,
  });

  @override
  State<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<SummarySheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _medalController;
  late Animation<double> _medalAnimation;
  bool _isPosting = false;
  
  String _privacidade = "TODOS";

  List<List<LatLng>> get _segments => widget.routeSegments ?? [widget.route];

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
    _medalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _medalAnimation = CurvedAnimation(
      parent: _medalController,
      curve: Curves.elasticOut,
    );
    _medalController.forward();
  }

  @override
  void dispose() {
    _medalController.dispose();
    super.dispose();
  }

  String _gerarTextoCompartilhamento() {
    final minutos = widget.duration ~/ 60;
    final segundos = widget.duration % 60;
    final tempoFormatado =
        '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
    final nomeAtividade = widget.tipoAtividade.toLowerCase();
    final iconeAtividade = nomeAtividade == "corrida" ? "🏃‍♂️" : "🚶‍♂️";

    return """
🧪 Experimento FitLab Concluído! 🧪
$iconeAtividade Acabei de bater ${widget.distance.toStringAsFixed(2)} km de $nomeAtividade!

⏱️ Tempo: $tempoFormatado
⚡ Pace: ${widget.pace}/km
📈 Ganhei +${widget.xp} XP no meu perfil.

Baixe o FitLab e venha pro laboratório também! 🧬
""";
  }

  void _compartilharExterno() {
    Navigator.pop(context);
    final texto = _gerarTextoCompartilhamento();
    Share.share(texto);
  }

  Future<void> _postarNoFeed(BuildContext context) async {
    // Salva as referências que dependem do context ANTES de fechar a tela 
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idUsuario = userProvider.usuarioLogado?.id ?? 1;
    final headers = _getAuthHeaders();

    setState(() => _isPosting = true);
    
    // Fecha o modal 
    Navigator.pop(context);

    // Usa a referência salva da tela principal para mostrar o SnackBar 
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text("Enviando para o feed..."),
        backgroundColor: Colors.white38,
        duration: Duration(seconds: 1),
      ),
    );

    final minutos = widget.duration ~/ 60;
    final segundos = widget.duration % 60;
    final tempoFormatado =
        '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';

    final String nomeAtividade = widget.tipoAtividade.toLowerCase();
    final String iconeAtividade = nomeAtividade == "corrida" ? "🏃‍♂️" : "🚶‍♂️";

    final rotaCodificada = RouteCodec.encode(_segments);

    final payload = {
      "titulo": "Finalizei meu treino de $nomeAtividade no FitLab! Percorri ${widget.distance.toStringAsFixed(2)} km em $minutos minutos!",
      "texto": "$iconeAtividade Distância: ${widget.distance.toStringAsFixed(2)} km \n⏱️ Tempo: $tempoFormatado \n⚡ Pace: ${widget.pace}/km \n📈 +${widget.xp} XP ganhos",
      "imagem": widget.route.isNotEmpty ? rotaCodificada : null,
      "privacidade": _privacidade, 
    };

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/atividades/compartilhar/$idUsuario',
    );

    try {
      final response = await http.post(
        url,
        headers: headers, 
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text("Publicado com sucesso no seu Feed! 🚀"),
            backgroundColor: Color(0xFF06B6D4),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Erro ao publicar: ${response.statusCode}"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erro ao postar: $e");
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Erro ao publicar. Verifique sua conexão."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 32, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "COMPARTILHAR RESULTADO",
                    style: TextStyle(
                      color: Color(0xFF06B6D4),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // SELETOR DE PRIVACIDADE
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => _privacidade = "TODOS");
                              setState(() => _privacidade = "TODOS");
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _privacidade == "TODOS" 
                                    ? const Color(0xFF06B6D4) 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.public, 
                                    size: 16, 
                                    color: _privacidade == "TODOS" ? Colors.black : Colors.white54
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Público", 
                                    style: TextStyle(
                                      color: _privacidade == "TODOS" ? Colors.black : Colors.white54, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 12
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => _privacidade = "AMIGOS");
                              setState(() => _privacidade = "AMIGOS");
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _privacidade == "AMIGOS" 
                                    ? const Color(0xFF06B6D4) 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.group, 
                                    size: 16, 
                                    color: _privacidade == "AMIGOS" ? Colors.black : Colors.white54
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Amigos", 
                                    style: TextStyle(
                                      color: _privacidade == "AMIGOS" ? Colors.black : Colors.white54, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 12
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _isPosting ? null : () => _postarNoFeed(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF06B6D4).withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: const [
                                  Icon(
                                    Icons.dynamic_feed_rounded,
                                    color: Color(0xFF06B6D4),
                                    size: 32,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "FitLab Feed",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _compartilharExterno,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                children: const [
                                  Icon(
                                    Icons.ios_share_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Outros Apps",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDarkTileLayer() {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.fitlab.app',
      tileBuilder: (context, widget, tile) {
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            -0.2126, -0.7152, -0.0722, 0, 255,
            -0.2126, -0.7152, -0.0722, 0, 255,
            -0.2126, -0.7152, -0.0722, 0, 255,
            0, 0, 0, 1, 0,
          ]),
          child: widget,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    LatLng mapCenter = widget.route.isNotEmpty
        ? widget.route[widget.route.length ~/ 2]
        : const LatLng(-21.1767, -47.8208);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [_buildDarkTileLayer()],
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: _medalAnimation,
                child: const Text("🥇", style: TextStyle(fontSize: 80)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  "EXPERIMENTO CONCLUÍDO",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Text(
                "Sua biometria evoluiu no Lab.",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                    color: Colors.black26,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCameraFit: widget.route.isNotEmpty
                            ? CameraFit.bounds(
                                bounds: LatLngBounds.fromPoints(widget.route),
                                padding: const EdgeInsets.all(40),
                              )
                            : null,
                        initialCenter: mapCenter,
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        _buildDarkTileLayer(),
                        if (widget.route.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              for (final segment in _segments)
                                Polyline(
                                  points: segment,
                                  color: const Color(0xFF06B6D4),
                                  strokeWidth: 5,
                                ),
                            ],
                          ),
                        if (widget.route.isNotEmpty)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: widget.route.first,
                                width: 36,
                                height: 36,
                                alignment: Alignment.topCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.greenAccent,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.flag,
                                    color: Colors.greenAccent,
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (widget.route.length > 1)
                                Marker(
                                  point: widget.route.last,
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.sports_score,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStat(
                      "DISTÂNCIA",
                      "${widget.distance.toStringAsFixed(2)} km",
                    ),
                    _buildStat("GANHOS", "+${widget.xp} XP", isXP: true),
                    _buildStat("RITMO", widget.pace),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showShareOptions(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(0, 55),
                        ),
                        child: const Text("COMPARTILHAR"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(0, 55),
                        ),
                        child: const Text(
                          "FECHAR",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String val, {bool isXP = false}) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            color: isXP ? const Color(0xFF06B6D4) : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}