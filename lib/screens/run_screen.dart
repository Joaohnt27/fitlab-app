import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/user_provider.dart';
import '../widgets/summary_sheets.dart';
import '../widgets/countdown_overlay.dart';
import '../config/api_constants.dart';
import '../models/run_tracker.dart';
import '../services/notification_service.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> with TickerProviderStateMixin {
  bool isRunning = false;
  bool isPaused = false;
  bool isCountingDown = false;
  int countdownValue = 5;

  final RunTracker _tracker = RunTracker();
  int get duration => _tracker.activeSeconds;
  double get distance => _tracker.distanceKm;
  String pace = "0:00";
  int steps = 0;
  int calories = 0;

  String selectedMode = "Corrida";
  String selectedGoalType = "Distância";
  double targetValue = 3.0;

  LatLng currentPosition = const LatLng(0, 0);
  double currentHeading = 0.0;

  List<List<LatLng>> get routeSegments => _tracker.segments;
  List<LatLng> get route => routeSegments.expand((segment) => segment).toList();

  final MapController _mapController = MapController();
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  bool _jaNotificouMeta = false; 

  final List<String> goalOptions = [
    "Distância",
    "Duração",
    "Calorias",
    "Passos",
    "Ganho de Elevação",
    "Sem Metas",
  ];

  final List<String> modeOptions = ["Corrida", "Caminhada"];

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndGetLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ative o GPS do celular.")));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentPosition = LatLng(position.latitude, position.longitude);
      _moveCameraToPlayer();
    });
  }

  void _moveCameraToPlayer() {
    if (currentPosition.latitude == 0 && currentPosition.longitude == 0) return;

    double offset = 0.0025;
    LatLng adjustedPosition = LatLng(
      currentPosition.latitude - offset,
      currentPosition.longitude,
    );
    _mapController.move(adjustedPosition, 17.0);
  }

  void _updateGoalValue(String type) {
    setState(() {
      selectedGoalType = type;
      switch (type) {
        case "Distância":
          targetValue = 3.0;
          break;
        case "Duração":
          targetValue = 20.0;
          break;
        case "Calorias":
          targetValue = 200.0;
          break;
        case "Passos":
          targetValue = 1000.0;
          break;
        case "Ganho de Elevação":
          targetValue = 500.0;
          break;
        case "Sem Metas":
          targetValue = 0.0;
          break;
      }
    });
  }

  void _triggerCountdown() {
    setState(() {
      isCountingDown = true;
      countdownValue = 6;
    });

    Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdownValue > 1) {
        setState(() => countdownValue--);
      } else {
        t.cancel();
        setState(() => isCountingDown = false);
        _startRun();
      }
    });
  }

  void _checarProgressoE_Notificar() {
    if (selectedGoalType == "Sem Metas") return;

    double progress = 0.0;
    if (targetValue > 0) {
      if (selectedGoalType == "Duração") {
        progress = (duration / (targetValue * 60));
      } else if (selectedGoalType == "Calorias") {
        progress = (calories / targetValue);
      } else if (selectedGoalType == "Passos") {
        progress = (steps / targetValue);
      } else {
        progress = (distance / targetValue);
      }
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isRunAlertsEnabled = userProvider.prefsNotificacoes['run_alerts'] ?? true;

    if (progress >= 1.0 && isRunAlertsEnabled && !_jaNotificouMeta) {
      _jaNotificouMeta = true;
      NotificationService().showNotification(
        title: 'Meta Atingida! 🥇', 
        body: 'Parabéns! Você concluiu 100% do seu objetivo de hoje no FitLab.',
      );
    }
  }

  void _startRun() {
    _jaNotificouMeta = false;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isRunAlertsEnabled = userProvider.prefsNotificacoes['run_alerts'] ?? true;
    
    if (isRunAlertsEnabled) {
      NotificationService().showNotification(
        title: 'Treino Iniciado 🏃‍♂️', 
        body: 'Bora suar a camisa no laboratório! O FitLab está monitorando.',
      );
    }

    setState(() {
      isRunning = true;
      isPaused = false;
      _tracker.start();
      pace = "0:00";
    });

    _moveCameraToPlayer();

    const distanceCalculator = Distance(
      roundResult: false,
      calculator: Haversine(),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          _tracker.tick();
          if (distance > 0) {
            double paceMinutes = (duration / 60) / distance;
            int mins = paceMinutes.floor();
            int secs = ((paceMinutes - mins) * 60).floor();
            pace = "$mins:${secs.toString().padLeft(2, '0')}";
          }
        });
        
        _checarProgressoE_Notificar();
      }
    });

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
          ),
        ).listen((Position position) {
          if (position.accuracy > RunTracker.maxAccuracyMeters) return;
          final newPosition = LatLng(position.latitude, position.longitude);
          final previous = _tracker.lastActivePosition;
          final accepted = _tracker.addPosition(
            newPosition,
            accuracy: position.accuracy,
            timestamp: DateTime.now().toIso8601String(),
          );
          if (!accepted) return;
          setState(() {
            if (previous != null &&
                distanceCalculator.distance(previous, newPosition) > 1.0) {
              currentHeading =
                  distanceCalculator.bearing(previous, newPosition) *
                  (pi / 180.0);
            }
            steps = (distance * 1200).toInt();
            calories = (distance * 55).toInt();
            currentPosition = newPosition;
            _moveCameraToPlayer();
          });
        });
  }

  void _pauseRun() {
    setState(() {
      _tracker.pause();
      isPaused = true;
    });
  }

  void _resumeRun() {
    setState(() {
      _tracker.resume();
      isPaused = false;
    });
  }

  Future<void> _stopRun() async {
    _tracker.stop();
    if (duration < 60 || distance < 0.05) {
      _timer?.cancel();
      _positionStream?.cancel();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Treino muito curto para ser registrado no Lab! 🧪"),
          backgroundColor: Colors.orange,
        ),
      );

      setState(() {
        isRunning = false;
        isPaused = false;
        _tracker.reset();
        steps = 0;
        calories = 0;
        currentHeading = 0.0;
        pace = "0:00";
        _jaNotificouMeta = false;
      });
      return;
    }

    _timer?.cancel();
    _positionStream?.cancel();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final idUsuario = userProvider.usuarioLogado?.id ?? 1;
    final token = userProvider.token;

    final body = jsonEncode({
      "idUsuario": idUsuario,
      "tipoAtividade": selectedMode,
      "tempo": _formatTime(duration),
      "pace": pace,
      "calorias": calories,
      "treinoPlanejado": false,
      "km": distance,
      "rota": _tracker.routeData,
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/atividades/registrar'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final recompensas = json.decode(utf8.decode(response.bodyBytes));
        int xpReal = recompensas['xpGanhos'] ?? 0;
        double distanciaOficial = recompensas['distanciaOficial'] ?? distance;

        await userProvider.recarregarUsuario();

        List<dynamic> badgesGanhas = [];
        if (recompensas['badgesDesbloqueadas'] != null) {
          badgesGanhas = recompensas['badgesDesbloqueadas'];
        }

        _showSummary(xpReal, distanciaOficial, badgesGanhas);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro na API: ${response.statusCode}")),
        );
        _showSummary(0, distance, []);
      }
    } catch (e) {
      debugPrint("Erro de conexão: $e");
      _showSummary(0, distance, []);
    }
  }

  void _showSummary(int xp, double finalDistance, List<dynamic> badgesGanhas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SummarySheet(
        tipoAtividade: selectedMode,
        route: route,
        routeSegments: routeSegments,
        distance: finalDistance,
        duration: duration,
        xp: xp,
        pace: pace,
        onClose: () {
          context.read<UserProvider>().ganharXPeVerificarLevelUp(context, xp);
          setState(() {
            isRunning = false;
            isPaused = false;
            _tracker.reset();
            pace = "0:00";
            steps = 0;
            calories = 0;
            currentHeading = 0.0;
            _jaNotificouMeta = false;
          });

          Navigator.pop(context);

          if (badgesGanhas.isNotEmpty) {
            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );

            Future.delayed(const Duration(milliseconds: 300), () {
              if (context.mounted) {
                for (var badge in badgesGanhas) {
                  userProvider.mostrarAlertaBadge(
                    context,
                    badge['nome'] ?? 'Nova Conquista',
                    badge['icone'] ?? '🏆',
                  );
                }
              }
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentPosition,
              initialZoom: 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
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
              ),
              if (route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final segment in routeSegments)
                      Polyline(
                        points: segment,
                        color: const Color(0xFF06B6D4),
                        strokeWidth: 5,
                      ),
                  ],
                ),
              if (currentPosition.latitude != 0)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPosition,
                      width: 70,
                      height: 70,
                      child: Transform.rotate(
                        angle: currentHeading,
                        child: _buildPlayerMarker(),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 25,
                bottom: 120,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D0D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 15,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isRunning ? _buildRunningHUD() : _buildSetupUI(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          if (isCountingDown) CountdownOverlay(value: countdownValue),
        ],
      ),
    );
  }

  Widget _buildSetupUI() {
    return Column(
      children: [
        Text(
          "META: ${selectedGoalType.toUpperCase()}",
          style: const TextStyle(
            color: Color(0xFF06B6D4),
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 15),
        if (selectedGoalType == "Sem Metas")
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "Treino Livre",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCircleButton(
                Icons.remove,
                () => setState(() => targetValue > 1 ? targetValue-- : null),
              ),
              const SizedBox(width: 30),
              Column(
                children: [
                  Text(
                    "${targetValue.toInt()}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getUnitLabel().toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF06B6D4),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 30),
              _buildCircleButton(
                Icons.add,
                () => setState(() => targetValue++),
              ),
            ],
          ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _showSelectionMenu("Modalidade", modeOptions),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getModeIcon(), color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                selectedMode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            _buildSmallActionBtn(
              Icons.flag,
              () => _showSelectionMenu("Meta", goalOptions),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: _triggerCountdown,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      "INICIAR",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            _buildSmallActionBtn(
              Icons.tune,
              () => _showSelectionMenu("Modalidade", modeOptions),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRunningHUD() {
    double progress = targetValue > 0 ? (distance / targetValue) : 0.0;
    if (selectedGoalType == "Duração") {
      progress = (duration / (targetValue * 60));
    } else if (selectedGoalType == "Calorias") {
      progress = (calories / targetValue);
    } else if (selectedGoalType == "Passos") {
      progress = (steps / targetValue);
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: selectedGoalType == "Sem Metas"
                    ? null
                    : progress.clamp(0.0, 1.0),
                strokeWidth: 8,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF06B6D4),
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  selectedMode == "Caminhada" ? "CAMINHANDO" : "CORRENDO",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  selectedGoalType == "Sem Metas"
                      ? "Livre"
                      : "${(progress * 100).toInt().clamp(0, 100)}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (selectedGoalType != "Sem Metas")
                  Text(
                    "de ${targetValue.toInt()} ${_getUnitLabel()}",
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 25),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statItem(
              Icons.timer_outlined,
              _formatTime(duration),
              "Duração",
              const Color(0xFF06B6D4),
            ),
            _statItem(
              Icons.location_on_outlined,
              distance.toStringAsFixed(2),
              "km",
              Colors.white,
            ),
            _statItem(Icons.speed_outlined, pace, "min/km", Colors.greenAccent),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statItem(
              Icons.local_fire_department_outlined,
              "$calories",
              "Calorias",
              Colors.orangeAccent,
            ),
            _statItem(
              Icons.directions_walk,
              "$steps",
              "Passos",
              Colors.white70,
            ),
          ],
        ),

        const SizedBox(height: 35),
        Row(
          children: [
            if (isPaused) ...[
              Expanded(
                child: _buildHUDButton("PARAR", Colors.redAccent, _stopRun),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHUDButton(
                  "CONTINUAR",
                  const Color(0xFF06B6D4),
                  _resumeRun,
                ),
              ),
            ] else
              Expanded(
                child: _buildHUDButton(
                  "PAUSAR",
                  Colors.white.withOpacity(0.05),
                  _pauseRun,
                  hasBorder: true,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _getUnitLabel() {
    switch (selectedGoalType) {
      case "Distância":
        return "km";
      case "Duração":
        return "min";
      case "Calorias":
        return "cal";
      case "Passos":
        return "passos";
      case "Ganho de Elevação":
        return "m";
      default:
        return "";
    }
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
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
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHUDButton(
    String label,
    Color color,
    VoidCallback onTap, {
    bool hasBorder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: hasBorder
              ? Border.all(color: const Color(0xFF06B6D4), width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon() {
    if (selectedMode == "Caminhada") return Icons.directions_walk;
    return Icons.directions_run; 
  }

  Widget _buildPlayerMarker() {
    return Center(
      child: Container(
        width: 22, 
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFF1D4ED8),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2.5,
          ), 
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D4ED8).withOpacity(0.6),
              blurRadius: 8,
              spreadRadius: 2, 
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white10,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildSmallActionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  String _formatTime(int seconds) {
    int mins = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return "${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  void _showSelectionMenu(String title, List<String> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 32, left: 24, right: 24),
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
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF06B6D4),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            
            ...options.map((opt) {
              bool isSelected = (title == "Meta" && selectedGoalType == opt) ||
                                (title == "Modalidade" && selectedMode == opt);

              return GestureDetector(
                onTap: () {
                  if (title == "Meta") {
                    _updateGoalValue(opt);
                  } else {
                    setState(() => selectedMode = opt);
                  }
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF06B6D4).withOpacity(0.1) 
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFF06B6D4).withOpacity(0.5) 
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildOptionIcon(opt, isSelected),
                      const SizedBox(width: 16),
                      Text(
                        opt,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF06B6D4) : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded, 
                          color: Color(0xFF06B6D4), 
                          size: 22,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionIcon(String option, bool isSelected) {
    IconData iconData;
    
    switch (option) {
      case "Distância": 
        iconData = Icons.map_outlined; 
        break;
      case "Duração": 
        iconData = Icons.timer_outlined; 
        break;
      case "Calorias": 
        iconData = Icons.local_fire_department_outlined; 
        break;
      case "Passos": 
        iconData = Icons.directions_walk_rounded; 
        break;
      case "Ganho de Elevação": 
        iconData = Icons.terrain_rounded; 
        break;
      case "Sem Metas": 
        iconData = Icons.all_inclusive_rounded; 
        break;
      case "Corrida": 
        iconData = Icons.directions_run_rounded; 
        break;
      case "Caminhada": 
        iconData = Icons.directions_walk_rounded; 
        break;
      default: 
        iconData = Icons.fitness_center;
    }

    return Icon(
      iconData,
      color: isSelected ? const Color(0xFF06B6D4) : Colors.white54,
      size: 24,
    );
  }
}