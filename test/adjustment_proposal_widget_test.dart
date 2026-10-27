import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitlab_mobile2/screens/plan_sessions_screen.dart';
import 'package:fitlab_mobile2/services/session_api.dart';

void main() {
  Map<String, dynamic> fixture(String state) => {
    'id': 1,
    'estado': state,
    'motivo': 'Fixture',
    'ajustesConsumidos': 1,
    'limiteAjustes': 6,
    'contexto': {
      'objetivoDisponivel': 'Objetivo salvo',
      'dataNegocio': '2026-10-25',
      'fuso': 'America/Sao_Paulo',
      'execucao': {
        'atividadeId': 9,
        'sessaoId': 7,
        'distanciaRealizadaKm': 4,
        'distanciaPlanejadaKm': 5,
        'duracaoAtivaSegundos': 1560,
        'duracaoPlanejadaSegundos': 1800,
        'paceRealizado': '6:30',
        'diferencaDistanciaKm': -1,
        'diferencaDuracaoSegundos': -240,
      },
      'elegiveis': [
        {
          'id': 8,
          'dataPlanejada': '2026-10-26',
          'descricao': 'Antes',
          'distanciaPlanejadaKm': 6,
          'duracaoPlanejadaSegundos': null,
        },
      ],
    },
    'proposta': {
      'justificativa': 'Fixture fundamentada nos dados registrados',
      'alteracoes': [
        {
          'sessaoId': 8,
          'descricao': 'Depois',
          'distanciaPlanejadaKm': 5,
          'duracaoPlanejadaSegundos': null,
        },
      ],
    },
  };
  for (final approve in [true, false]) {
    testWidgets(
      'proposal review and ${approve ? 'approval' : 'refusal'} use server data and persist state',
      (tester) async {
        var state = 'PENDENTE';
        var posts = 0;
        final service = SessionApi(
          token: 'fixture',
          baseUrl: 'http://local.invalid/api',
          client: MockClient((r) async {
            if (r.method == 'POST') {
              posts++;
              expect(jsonDecode(r.body), {'aprovar': approve});
              state = approve ? 'APROVADA' : 'RECUSADA';
            }
            return http.Response(
              jsonEncode(fixture(state)),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(home: AdjustmentProposalScreen(id: 1, api: service)),
        );
        await tester.pumpAndSettle();
        expect(posts, 0);
        expect(find.textContaining('Distância: 4 km'), findsOneWidget);
        final button = find.text(
          approve ? 'Confirmar proposta' : 'Recusar proposta',
        );
        await tester.scrollUntilVisible(button, 300);
        await tester.pumpAndSettle();
        expect(find.text('Depois'), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(approve ? 'Aprovada' : 'Recusada'),
          -300,
        );
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(find.text(approve ? 'Aprovada' : 'Recusada'), findsOneWidget);
      },
    );
  }
  testWidgets('stale proposal is explained and cannot be confirmed again', (
    tester,
  ) async {
    var state = 'PENDENTE';
    var posts = 0;
    final service = SessionApi(
      token: 'fixture',
      baseUrl: 'http://local.invalid/api',
      client: MockClient((r) async {
        final p = fixture(state);
        if (r.method == 'POST') {
          posts++;
          state = 'DESATUALIZADA';
          return http.Response('{"erro":"Proposta desatualizada"}', 409);
        }
        if (state == 'DESATUALIZADA') {
          p['erro'] = 'Proposta desatualizada: solicite nova analise.';
        }
        return http.Response(
          jsonEncode(p),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: AdjustmentProposalScreen(id: 1, api: service)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Confirmar proposta'), 300);
    await tester.tap(find.text('Confirmar proposta'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('Confirmar proposta'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('Proposta desatualizada:'),
      -300,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Proposta desatualizada:'), findsOneWidget);
  });
  testWidgets(
    'completed execution requests review without applying and returns to persisted history',
    (tester) async {
      var state = 'PENDENTE';
      var generated = false;
      var callbacks = 0;
      var generations = 0;
      final service = SessionApi(
        token: 'fixture',
        baseUrl: 'http://local.invalid/api',
        client: MockClient((r) async {
          dynamic response;
          if (r.url.path.endsWith('/decisao')) {
            expect(jsonDecode(r.body), {'aprovar': true});
            state = 'APROVADA';
            response = fixture(state);
          } else if (r.url.path.endsWith('/propostas-ajuste')) {
            if (r.method == 'POST') {
              generations++;
              generated = true;
              expect(
                jsonDecode(r.body).keys,
                unorderedEquals(['tentativaId', 'motivo']),
              );
              response = fixture(state);
            } else {
              response = generated ? [fixture(state)] : [];
            }
          } else {
            response = fixture(state);
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReavaliacaoCard(
                sessaoId: 7,
                api: service,
                onApplied: () {
                  callbacks++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(generations, 0);
      await tester.tap(find.text('Reavaliar próximas sessões'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Menos tempo nesta semana',
      );
      await tester.tap(find.text('Solicitar análise'));
      await tester.pumpAndSettle();
      expect(generations, 1);
      expect(state, 'PENDENTE');
      await tester.scrollUntilVisible(find.text('Confirmar proposta'), 300);
      await tester.tap(find.text('Confirmar proposta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(callbacks, 1);
      expect(find.textContaining('Proposta #1 • Aprovada'), findsOneWidget);
    },
  );
}
