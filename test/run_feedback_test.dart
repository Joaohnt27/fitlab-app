import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitlab_mobile2/widgets/run_feedback.dart';

void main() {
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
    const output = String.fromEnvironment('FITLAB_RUN_PREVIEW');
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

  testWidgets('saving and preparing summary prevent a duplicate retry action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    final key = GlobalKey();
    Widget screen({bool saved = false}) => MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RunSaveNotice(
              saving: !saved,
              saved: saved,
              onRetry: () => retries++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pump();
    expect(find.text('Salvando atividade...'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    await capture(tester, key, 'salvando');
    await tester.pumpWidget(screen(saved: true));
    await tester.pump();
    expect(find.text('Preparando seu resumo...'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(retries, 0);
  });

  testWidgets(
    'failure stays readable at 320px with larger text and offers retry',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retries = 0;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.4)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: const Color(0xFF0D0D0D),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: RunSaveNotice(
                  saving: false,
                  error:
                      'Entre na mesma conta para salvar esta corrida. Os dados continuam nesta tela.',
                  onRetry: () => retries++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'erro-salvamento');
      await tester.tap(find.text('Tentar salvar novamente'));
      expect(retries, 1);
    },
  );

  testWidgets('run warning is readable without inheriting light theme colors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  runFeedbackSnackBar(
                    title: 'GPS desativado',
                    message:
                        'Ative o GPS do celular para acompanhar o percurso.',
                    icon: Icons.location_off_rounded,
                    warning: true,
                  ),
                ),
                child: const Text('Aviso'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aviso'));
    await tester.pumpAndSettle();
    expect(find.text('GPS desativado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'aviso-gps');
  });
}
