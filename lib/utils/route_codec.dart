import 'dart:convert';
import 'package:latlong2/latlong.dart';

class RouteCodec {
  static const prefix = 'fitlab-route-v2:';

  static String? encode(List<List<LatLng>> segments) {
    final nonEmpty = segments.where((s) => s.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return null;
    final total = nonEmpty.fold<int>(0, (n, s) => n + s.length);
    final step = (total / 50).ceil();
    final sampled = [
      for (final segment in nonEmpty)
        [
          for (var i = 0; i < segment.length; i += step) segment[i],
          if ((segment.length - 1) % step != 0) segment.last,
        ],
    ];
    if (sampled.length == 1) {
      return sampled.single
          .map(
            (p) =>
                '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}',
          )
          .join('|');
    }
    return prefix +
        jsonEncode([
          for (final segment in sampled)
            [
              for (final p in segment)
                [
                  double.parse(p.latitude.toStringAsFixed(5)),
                  double.parse(p.longitude.toStringAsFixed(5)),
                ],
            ],
        ]);
  }

  static List<List<LatLng>> decode(String? value) {
    if (value == null || value.isEmpty || value.startsWith('http')) return [];
    try {
      if (value.startsWith(prefix)) {
        final raw = jsonDecode(value.substring(prefix.length)) as List;
        return [
          for (final segment in raw)
            [
              for (final p in segment as List)
                LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            ],
        ].where((s) => s.isNotEmpty).toList();
      }
      final points = <LatLng>[];
      for (final point in value.split('|')) {
        final coords = point.split(',');
        if (coords.length != 2) return [];
        final lat = double.tryParse(coords[0]);
        final lng = double.tryParse(coords[1]);
        if (lat == null || lng == null) return [];
        points.add(LatLng(lat, lng));
      }
      return [points];
    } catch (_) {
      return [];
    }
  }
}
