import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitlab_mobile2/screens/plan_sessions_screen.dart';
import 'package:fitlab_mobile2/services/session_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fonts = String.fromEnvironment('FITLAB_FONT_DIR');
    if (fonts.isEmpty) return;
    Future<ByteData> read(String name) async =>
        ByteData.sublistView(await File('$fonts/$name').readAsBytes());
    await (FontLoader('Roboto')
          ..addFont(read('Roboto-Regular.ttf'))
          ..addFont(read('Roboto-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(read('MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    const output = String.fromEnvironment('FITLAB_SCREENSHOTS');
    if (output.isEmpty) return;
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('sessions and plans fit a narrow display with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = SessionApi(
      token: 'fixture',
      baseUrl: 'http://local.invalid/api',
      client: MockClient((r) async {
        final sessions = [
          {
            'id': 1,
            'dataPlanejada': '2026-11-01',
            'status': 'AGENDADO',
            'descricao': 'Corrida leve para desenvolver consistencia',
            'distanciaPlanejadaKm': 5,
            'duracaoPlanejadaSegundos': 1800,
          },
          {
            'id': 2,
            'dataPlanejada': '2026-11-02',
            'status': 'DESCANSO',
            'descricao': 'Descanso',
          },
          {
            'id': 3,
            'dataPlanejada': '2026-11-03',
            'status': 'CONCLUIDO',
            'descricao': 'Caminhada e corrida leve',
            'distanciaPlanejadaKm': 4,
          },
        ];
        final plans = [
          {
            'id': 1,
            'titulo': 'Plano de corrida para retomar a rotina com consistencia',
            'dataAtivacao': '2026-10-26',
            'conteudo': {},
          },
        ];
        return http.Response(
          jsonEncode(r.url.path.endsWith('/sessoes') ? sessions : plans),
          200,
        );
      }),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: key,
          child: PlanSessionsScreen(api: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('AGENDADA'), findsOneWidget);
    expect(find.text('DESCANSO'), findsOneWidget);
    await capture(tester, key, 'sessoes');
    await tester.tap(find.text('PLANOS'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ATIVADO'), findsOneWidget);
    await capture(tester, key, 'planos');
  });

  testWidgets(
    'completed session detail fits narrow screens and remains scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = SessionApi(
        token: 'fixture',
        baseUrl: 'http://local.invalid/api',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'id': 1,
              'dataPlanejada': '2026-11-01',
              'status': 'CONCLUIDO',
              'descricao': 'Corrida leve para desenvolver consistencia.',
              'distanciaPlanejadaKm': 5,
              'duracaoPlanejadaSegundos': 1800,
              'comparacao': {
                'distanciaRealizadaKm': 4,
                'duracaoAtivaSegundos': 1560,
                'paceRealizado': '6:30',
                'diferencaDistanciaKm': -1,
                'diferencaDuracaoSegundos': -240,
              },
            }),
            200,
          ),
        ),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: SessionDetailScreen(id: 1, api: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'detalhe-sessao');
      await tester.scrollUntilVisible(
        find.text('Diferença de duração: -240 s'),
        200,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'comparacao');
    },
  );
  testWidgets('activation panel keeps controls readable at narrow widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = SessionApi(
      token: 'fixture',
      baseUrl: 'http://local.invalid/api',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'ativavel': true,
            'regraDatas':
                'Dia N = data inicial + (N - 1) dias corridos. Descanso nao permite iniciar corrida.',
          }),
          200,
        ),
      ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PlanActivationCard(planoId: 1, api: service),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Escolher data inicial'), findsOneWidget);
    expect(find.text('Não ativar agora'), findsOneWidget);
    await capture(tester, key, 'ativar-plano');
  });
}
