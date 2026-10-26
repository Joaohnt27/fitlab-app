import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitlab_mobile2/screens/plan_sessions_screen.dart';
import 'package:fitlab_mobile2/services/session_api.dart';

void main() {
  SessionApi api(MockClient client) => SessionApi(
    token: 'fixture',
    client: client,
    baseUrl: 'http://local.invalid/api',
  );
  testWidgets(
    'viewing a proposal makes no POST; confirmation uses the date chosen',
    (tester) async {
      var posts = 0;
      var active = false;
      final service = api(
        MockClient((r) async {
          if (r.method == 'POST') {
            posts++;
            expect(jsonDecode(r.body)['dataInicio'], '2026-11-01');
            active = true;
            return http.Response('[]', 200);
          }
          return http.Response(
            jsonEncode({
              'id': 1,
              'ativavel': !active,
              'dataAtivacao': active ? '2026-10-26' : null,
              'dataInicio': '2026-11-01',
              'regraDatas': 'Dia N = inicio + N-1 dias.',
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanActivationCard(
              planoId: 1,
              api: service,
              initialDate: DateTime(2026, 11, 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(posts, 0);
      final confirm = find.text('Confirmar plano e criar sessões');
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(
                ElevatedButton,
                'Confirmar plano e criar sessões',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Escolher data inicial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('Ver sessões'), findsOneWidget);
    },
  );
  testWidgets('legacy limitation is visible without creating a session', (
    tester,
  ) async {
    final service = api(
      MockClient((r) async {
        expect(r.method, 'GET');
        return http.Response(
          '{"ativavel":false,"limitacao":"Plano antigo sem dias estruturados"}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlanActivationCard(planoId: 1, api: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plano antigo sem dias estruturados'), findsOneWidget);
    expect(find.text('Confirmar plano e criar sessões'), findsNothing);
  });
  testWidgets(
    'completed session displays server comparison after reload without inventing missing goals',
    (tester) async {
      var gets = 0;
      final service = api(
        MockClient((r) async {
          gets++;
          return http.Response(
            jsonEncode({
              'id': 7,
              'dataPlanejada': '2026-11-01',
              'status': 'CONCLUIDO',
              'descricao': 'Fixture',
              'distanciaPlanejadaKm': null,
              'duracaoPlanejadaSegundos': null,
              'comparacao': {
                'distanciaRealizadaKm': 4,
                'duracaoAtivaSegundos': 1560,
                'paceRealizado': '6:30',
                'diferencaDistanciaKm': null,
                'diferencaDuracaoSegundos': null,
              },
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: SessionDetailScreen(id: 7, api: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Distância planejada: Não prescrita'), findsOneWidget);
      expect(find.text('Distância realizada: 4.00 km'), findsOneWidget);
      expect(find.text('Iniciar esta sessão'), findsNothing);
      expect(find.textContaining('Diferença'), findsNothing);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(gets, 2);
      expect(find.text('Pace realizado: 6:30 /km'), findsOneWidget);
    },
  );
}
