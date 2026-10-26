import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fitlab_mobile2/utils/route_codec.dart';

void main() {
  test('segmented feed route survives encoding without a pause bridge', () {
    const segments = [
      [LatLng(0, 0), LatLng(0, .001)],
      [LatLng(0, .004), LatLng(0, .005)],
    ];
    final encoded = RouteCodec.encode(segments)!;
    expect(encoded, startsWith(RouteCodec.prefix));
    expect(RouteCodec.decode(encoded), segments);
  });

  test('legacy post is read as one segment without invented pauses', () {
    expect(RouteCodec.decode('0.00000,0.00000|0.00000,0.00100'), [
      [const LatLng(0, 0), const LatLng(0, .001)],
    ]);
  });

  test('new continuous route keeps legacy encoding', () {
    expect(
      RouteCodec.encode([
        [const LatLng(0, 0), const LatLng(0, .001)],
      ]),
      '0.00000,0.00000|0.00000,0.00100',
    );
  });

  test('sampling preserves endpoints of every segment', () {
    final segments = [
      [for (var i = 0; i < 101; i++) LatLng(0, i / 1000)],
      [for (var i = 200; i < 301; i++) LatLng(0, i / 1000)],
    ];
    final decoded = RouteCodec.decode(RouteCodec.encode(segments));
    expect(decoded.length, 2);
    for (var i = 0; i < 2; i++) {
      expect(decoded[i].first, segments[i].first);
      expect(decoded[i].last, segments[i].last);
    }
  });

  test('empty, image URLs and malformed routes do not produce a polyline', () {
    expect(RouteCodec.encode([]), isNull);
    for (final value in [
      null,
      '',
      'https://example.invalid/image.png',
      'not,a,route',
      '${RouteCodec.prefix}broken',
      '${RouteCodec.prefix}[[[0]]]',
    ]) {
      expect(RouteCodec.decode(value), isEmpty);
    }
  });
}
