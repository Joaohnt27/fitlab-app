import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitlab_mobile2/models/adjustment_attempt.dart';
import 'package:fitlab_mobile2/services/session_api.dart';

void main() {
  SessionApi api(MockClient c) => SessionApi(
    token: 'fixture',
    client: c,
    baseUrl: 'http://local.invalid/api',
  );
  test(
    'lost response retries same attempt without accepting client performance metrics',
    () async {
      final bodies = <String>[];
      final service = api(
        MockClient((r) async {
          bodies.add(r.body);
          if (bodies.length == 1) throw http.ClientException('fixture');
          return http.Response('{"id":1,"estado":"PENDENTE"}', 200);
        }),
      );
      final attempt = AdjustmentAttempt(motivo: 'Motivo fixo');
      expect(await attempt.send(service, 7), isNull);
      expect(attempt.error, isNotNull);
      expect((await attempt.send(service, 7))!['id'], 1);
      expect(bodies[0], bodies[1]);
      expect(
        jsonDecode(bodies[0]).keys,
        unorderedEquals(['tentativaId', 'motivo']),
      );
      await attempt.send(service, 7);
      expect(bodies.length, 2);
    },
  );
  test('double tap does not send concurrent calls', () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final service = api(
      MockClient((_) {
        calls++;
        return response.future;
      }),
    );
    final attempt = AdjustmentAttempt(motivo: '');
    final first = attempt.send(service, 7);
    expect(await attempt.send(service, 7), isNull);
    response.complete(http.Response('{"id":1,"estado":"PROCESSANDO"}', 202));
    await first;
    expect(calls, 1);
    expect(attempt.result!['estado'], 'PROCESSANDO');
  });
  test('recovered interrupted proposal preserves its original key', () async {
    final service = api(
      MockClient((r) async {
        expect(jsonDecode(r.body)['tentativaId'], 'original');
        return http.Response('{"id":1,"estado":"PENDENTE"}', 200);
      }),
    );
    await AdjustmentAttempt(
      motivo: '',
      tentativaId: 'original',
    ).send(service, 7);
  });
}
