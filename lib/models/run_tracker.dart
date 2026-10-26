import 'package:latlong2/latlong.dart';

class RunTracker {
  static const maxAccuracyMeters = 15.0;
  static const _distance = Distance(
    roundResult: false,
    calculator: Haversine(),
  );

  bool _running = false;
  bool _paused = false;
  int activeSeconds = 0;
  double distanceKm = 0;
  LatLng? lastActivePosition;
  final List<List<LatLng>> _segments = [];
  final List<Map<String, dynamic>> _routeData = [];

  List<List<LatLng>> get segments => [
    for (final segment in _segments) List.unmodifiable(segment),
  ];
  List<Map<String, dynamic>> get routeData => [
    for (final point in _routeData) Map.of(point),
  ];

  void reset() {
    _running = false;
    _paused = false;
    activeSeconds = 0;
    distanceKm = 0;
    lastActivePosition = null;
    _segments.clear();
    _routeData.clear();
  }

  void start() {
    reset();
    _running = true;
  }

  void tick() {
    if (_running && !_paused) activeSeconds++;
  }

  void pause() {
    if (!_running) return;
    _paused = true;
    lastActivePosition = null;
  }

  void resume() {
    if (!_running || !_paused) return;
    _paused = false;
    lastActivePosition = null;
  }

  void stop() {
    _running = false;
    lastActivePosition = null;
  }

  bool addPosition(
    LatLng point, {
    required double accuracy,
    required String timestamp,
  }) {
    if (!_running ||
        _paused ||
        !accuracy.isFinite ||
        accuracy > maxAccuracyMeters) {
      return false;
    }
    final previous = lastActivePosition;
    if (previous == null) {
      _segments.add([]);
    } else {
      distanceKm += _distance.distance(previous, point) / 1000;
    }
    _segments.last.add(point);
    _routeData.add({
      'lat': point.latitude,
      'lng': point.longitude,
      'timestamp': timestamp,
      'segmento': _segments.length - 1,
    });
    lastActivePosition = point;
    return true;
  }
}
