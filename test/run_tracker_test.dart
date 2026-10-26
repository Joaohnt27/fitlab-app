import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fitlab_mobile2/models/run_tracker.dart';

void main() {
  const a = LatLng(0, 0);
  const b = LatLng(0, .001);
  const c = LatLng(0, .004);
  const d = LatLng(0, .005);
  const e = LatLng(0, .008);
  const f = LatLng(0, .009);
  const calculator = Distance(roundResult: false, calculator: Haversine());
  final legKm = calculator.distance(a, b) / 1000;
  late RunTracker tracker;

  bool point(LatLng position, {double accuracy = 5}) => tracker.addPosition(
    position,
    accuracy: accuracy,
    timestamp: '2026-10-26T12:00:00Z',
  );
  void seconds(int count) {
    for (var i = 0; i < count; i++) {
      tracker.tick();
    }
  }

  setUp(() {
    tracker = RunTracker()..start();
  });

  test('A-B, paused B-C, resumed C-D: only active legs and time', () {
    point(a);
    seconds(60);
    point(b);
    tracker.pause();
    seconds(30);
    expect(point(c), isFalse);
    expect(tracker.distanceKm, closeTo(legKm, 1e-9));
    expect(tracker.activeSeconds, 60);
    tracker.resume();
    expect(point(c), isTrue);
    expect(tracker.distanceKm, closeTo(legKm, 1e-9));
    seconds(60);
    point(d);
    tracker.stop();
    expect(tracker.distanceKm, closeTo(2 * legKm, 1e-9));
    expect(tracker.activeSeconds, 120);
    expect(tracker.segments, [
      [a, b],
      [c, d],
    ]);
    expect(tracker.routeData.map((p) => p['segmento']), [0, 0, 1, 1]);
  });

  test('without pause retains a continuous route', () {
    point(a);
    seconds(60);
    point(b);
    point(c);
    point(d);
    expect(tracker.distanceKm, closeTo(calculator.distance(a, d) / 1000, 1e-9));
    expect(tracker.segments, [
      [a, b, c, d],
    ]);
    expect(tracker.activeSeconds, 60);
  });

  test('multiple pauses never join active segments', () {
    point(a);
    point(b);
    tracker.pause();
    point(c);
    tracker.resume();
    point(c);
    point(d);
    tracker.pause();
    point(e);
    tracker.resume();
    point(e);
    point(f);
    expect(tracker.distanceKm, closeTo(3 * legKm, 1e-9));
    expect(tracker.segments, [
      [a, b],
      [c, d],
      [e, f],
    ]);
  });

  test('finishing while paused preserves only the active data', () {
    point(a);
    seconds(60);
    point(b);
    tracker.pause();
    seconds(20);
    point(c);
    tracker.stop();
    tracker.resume();
    seconds(10);
    expect(point(d), isFalse);
    expect(tracker.distanceKm, closeTo(legKm, 1e-9));
    expect(tracker.activeSeconds, 60);
    expect(tracker.segments, [
      [a, b],
    ]);
  });

  test('poor accuracy after resume does not establiish a reference', () {
    point(a);
    point(b);
    tracker.pause();
    tracker.resume();
    expect(point(c, accuracy: 16), isFalse);
    expect(tracker.lastActivePosition, isNull);
    point(d); 
    expect(tracker.distanceKm, closeTo(legKm, 1e-9));
    point(e);
    expect(tracker.distanceKm, closeTo(4 * legKm, 1e-9));
    expect(tracker.segments, [
      [a, b],
      [d, e],
    ]);
  });

  test('new run resets distance, duration, reference and segment IDs', () {
    point(a);
    seconds(60);
    point(b);
    tracker.stop();
    tracker.start();
    expect(tracker.distanceKm, 0);
    expect(tracker.activeSeconds, 0);
    expect(tracker.segments, isEmpty);
    expect(tracker.routeData, isEmpty);
    point(e);
    expect(tracker.distanceKm, 0);
    point(f);
    expect(tracker.distanceKm, closeTo(legKm, 1e-9));
    expect(tracker.segments, [
      [e, f],
    ]);
    expect(tracker.routeData.first['segmento'], 0);
  });

  test('repeated pause before another valid fix creates no empty segment', () {
    point(a);
    point(b);
    tracker.pause();
    tracker.resume();
    tracker.pause();
    tracker.resume();
    point(c);
    expect(tracker.segments, [
      [a, b],
      [c],
    ]);
    expect(tracker.distanceKm, closeTo(legKm, 1e-9));
  });
}
