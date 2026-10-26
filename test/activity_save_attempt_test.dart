import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitlab_mobile2/models/activity_save_attempt.dart';
import 'package:fitlab_mobile2/services/session_api.dart';

void main() {
  SessionApi api(MockClient client) => SessionApi(
    token: 'fixture',
    client: client,
    baseUrl: 'http://local.invalid/api',
  );
  test(
    'network failure keeps one immutable attempt and a retry uses identical data',
    () async {
      final bodies = <String>[];
      var calls = 0;
      final payload = <String, dynamic>{
        'sessaoId': 7,
        'km': 2.0,
        'duracaoAtivaSegundos': 600,
        'rota': [
          {'lat': 0, 'lng': 0, 'segmento': 0},
          {'lat': 1, 'lng': 1, 'segmento': 1},
        ],
      };
      final attempt = ActivitySaveAttempt(payload);
      final service = api(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer fixture');
          bodies.add(request.body);
          if (++calls == 1) {
            throw http.ClientException('Local fixture, no network');
          }
          return http.Response('{"xpGanhos":20,"distanciaOficial":2}', 200);
        }),
      );
      payload['km'] = 900;
      (payload['rota'] as List).clear();
      expect(await attempt.save(service), isNull);
      expect(attempt.result, isNull);
      expect(attempt.error, isNotNull);
      expect((await attempt.save(service))!['xpGanhos'], 20);
      expect(bodies[0], bodies[1]);
      final saved = jsonDecode(bodies.first);
      expect(saved['km'], 2);
      expect(saved['rota'].length, 2);
      expect(
        saved['tentativaId'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      await attempt.save(service);
      expect(calls, 2); 
    },
  );
  test('double tap during pending save sends only one request', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final service = api(
      MockClient((request) {
        calls++;
        return pending.future;
      }),
    );
    final attempt = ActivitySaveAttempt({'km': 1});
    final first = attempt.save(service);
    expect(attempt.saving, isTrue);
    expect(await attempt.save(service), isNull);
    pending.complete(
      http.Response('{"xpGanhos":10,"distanciaOficial":1}', 200),
    );
    await first;
    expect(calls, 1);
  });
  test(
    'HTTP rejection does not produce a success result and can be retried',
    () async {
      var calls = 0;
      final service = api(
        MockClient(
          (_) async => ++calls == 1
              ? http.Response('{"erro":"Fixture rejected"}', 500)
              : http.Response('{"xpGanhos":10,"distanciaOficial":1}', 200),
        ),
      );
      final attempt = ActivitySaveAttempt({'km': 1});
      expect(await attempt.save(service), isNull);
      expect(attempt.error, isNotNull);
      expect(attempt.saving, isFalse);
      expect(await attempt.save(service), isNotNull);
    },
  );
  test(
    'free run keeps a null session and each new run has its own attempt',
    () async {
      final payloads = <dynamic>[];
      final service = api(
        MockClient((r) async {
          payloads.add(jsonDecode(r.body));
          return http.Response('{"xpGanhos":10,"distanciaOficial":1}', 200);
        }),
      );
      await ActivitySaveAttempt({
        'sessaoId': null,
        'km': 1,
        'duracaoAtivaSegundos': 600,
      }).save(service);
      await ActivitySaveAttempt({
        'sessaoId': null,
        'km': 1,
        'duracaoAtivaSegundos': 600,
      }).save(service);
      expect(payloads[0]['sessaoId'], isNull);
      expect(payloads[0]['tentativaId'], isNot(payloads[1]['tentativaId']));
    },
  );
  test('malformed success response keeps the attempt pending', () async {
    final attempt = ActivitySaveAttempt({'km': 1});
    final service = api(MockClient((_) async => http.Response('{}', 200)));
    expect(await attempt.save(service), isNull);
    expect(attempt.result, isNull);
    expect(attempt.error, isNotNull);
  });
}
