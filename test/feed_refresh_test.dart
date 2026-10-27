import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitlab_mobile2/models/user_model.dart';
import 'package:fitlab_mobile2/providers/user_provider.dart';
import 'package:fitlab_mobile2/screens/feed_screen.dart';
import 'package:fitlab_mobile2/services/session_api.dart';
import 'package:fitlab_mobile2/widgets/feed_card.dart';

class FixtureUser extends UserProvider {
  int account = 7;
  @override
  UserModel get usuarioLogado => UserModel(
    id: account,
    nome: 'Fixture',
    email: 'fixture@example.test',
    senha: '',
  );
  @override
  String get token => 'fixture-$account';
  void changeAccount(int id) {
    account = id;
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Map<String, dynamic> post(int id, String title) => {
    'id': id,
    'nomeUsuario': 'Fixture',
    'titulo': title,
    'likes': 0,
  };
  Future<void> mount(
    WidgetTester tester,
    FixtureUser user,
    SessionApi api,
    ValueNotifier<bool> visible,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: user,
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, active, _) => IndexedStack(
              index: active ? 0 : 1,
              children: [
                FeedScreen(active: active, api: api),
                const Scaffold(body: Text('Outra aba')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  http.Response reply(dynamic data) => http.Response(
    jsonEncode(data),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  http.Response auxiliary(http.Request r) => reply(
    r.url.path.endsWith('/perfil')
        ? {
            'nivel': {'xpAtual': 10, 'nomePatente': 'Recruta'},
          }
        : r.url.path.endsWith('/ativo')
        ? null
        : [],
  );

  testWidgets(
    'returning to a retained tab refreshes its data and publication notifies it',
    (tester) async {
      final user = FixtureUser();
      final visible = ValueNotifier(true);
      var version = 0;
      var reads = 0;
      final api = SessionApi(
        token: 'fixture-7',
        baseUrl: 'http://local.invalid/api',
        client: MockClient((r) async {
          if (r.url.path.contains('/social/')) {
            reads++;
            return reply([
              post(
                version + 1,
                version == 0 ? 'Publicação original' : 'Publicação nova',
              ),
            ]);
          }
          return auxiliary(r);
        }),
      );
      await mount(tester, user, api, visible);
      expect(reads, 1);
      visible.value = false;
      await tester.pumpAndSettle();
      version++;
      await tester.pump(const Duration(seconds: 60));
      expect(reads, 1);
      visible.value = true;
      await tester.pumpAndSettle();
      expect(reads, 2);
      await tester.scrollUntilVisible(find.text('Publicação nova'), 400);
      expect(find.text('Publicação nova'), findsOneWidget);
      version++;
      user.notificarFeedAtualizado();
      await tester.pumpAndSettle();
      expect(reads, 3);
      await tester.pumpWidget(const SizedBox());
      user.dispose();
      visible.dispose();
      api.close();
    },
  );

  testWidgets(
    'polls only the visible foreground feed and refreshes on resume',
    (tester) async {
      final user = FixtureUser();
      final visible = ValueNotifier(true);
      var reads = 0;
      var otherReads = 0;
      final api = SessionApi(
        token: 'fixture-7',
        baseUrl: 'http://local.invalid/api',
        client: MockClient((r) async {
          if (r.url.path.contains('/social/')) {
            reads++;
            return reply([]);
          }
          otherReads++;
          return auxiliary(r);
        }),
      );
      await mount(tester, user, api, visible);
      expect(reads, 1);
      expect(otherReads, 4);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(otherReads, 4);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(reads, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(otherReads, 8);
      visible.value = false;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 60));
      expect(reads, 3);
      await tester.pumpWidget(const SizedBox());
      user.dispose();
      visible.dispose();
      api.close();
    },
  );

  testWidgets('automatic refresh does not interrupt reading older posts', (
    tester,
  ) async {
    final user = FixtureUser();
    final visible = ValueNotifier(true);
    var reads = 0;
    final api = SessionApi(
      token: 'fixture-7',
      baseUrl: 'http://local.invalid/api',
      client: MockClient((r) async {
        if (r.url.path.contains('/social/')) {
          reads++;
          return reply(List.generate(10, (i) => post(i, 'Post $i')));
        }
        return auxiliary(r);
      }),
    );
    await mount(tester, user, api, visible);
    await tester.scrollUntilVisible(find.text('Post 5'), 400);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(reads, 1);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox());
    user.dispose();
    visible.dispose();
    api.close();
  });

  testWidgets(
    'covering the feed stops polling and returning to its route refreshes',
    (tester) async {
      final user = FixtureUser();
      final visible = ValueNotifier(true);
      var reads = 0;
      final api = SessionApi(
        token: 'fixture-7',
        baseUrl: 'http://local.invalid/api',
        client: MockClient((r) async {
          if (r.url.path.contains('/social/')) {
            reads++;
            return reply([]);
          }
          return auxiliary(r);
        }),
      );
      await mount(tester, user, api, visible);
      final navigator = Navigator.of(tester.element(find.byType(FeedScreen)));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra tela')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 60));
      expect(reads, 1);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox());
      user.dispose();
      visible.dispose();
      api.close();
    },
  );

  testWidgets(
    'manual refresh works for an empty feed and dispose ignores pending response',
    (tester) async {
      final user = FixtureUser();
      final visible = ValueNotifier(true);
      var reads = 0;
      final pending = Completer<http.Response>();
      final api = SessionApi(
        token: 'fixture-7',
        baseUrl: 'http://local.invalid/api',
        client: MockClient((r) async {
          if (r.url.path.contains('/social/')) {
            return ++reads == 1 ? reply([]) : pending.future;
          }
          return auxiliary(r);
        }),
      );
      await mount(tester, user, api, visible);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 450));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox());
      pending.complete(reply([post(1, 'Resposta atrasada')]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      user.dispose();
      visible.dispose();
      api.close();
    },
  );

  testWidgets('old account responses cannot replace the current account feed', (
    tester,
  ) async {
    final user = FixtureUser();
    final visible = ValueNotifier(true);
    final old = Completer<http.Response>();
    final paths = <String>[];
    final api = SessionApi(
      token: 'fixture-only',
      baseUrl: 'http://local.invalid/api',
      client: MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path.endsWith('/social/7')) return old.future;
        if (r.url.path.endsWith('/social/8')) {
          return reply([post(8, 'Conta atual')]);
        }
        return auxiliary(r);
      }),
    );
    // Do not settle while the first account's loading indicator is intentionally pending.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: user,
        child: MaterialApp(
          home: FeedScreen(api: api, autoRefreshInterval: Duration.zero),
        ),
      ),
    );
    await tester.pump();
    user.changeAccount(8);
    await tester.pumpAndSettle();
    old.complete(reply([post(7, 'Conta anterior')]));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Conta atual'), 400);
    expect(find.text('Conta anterior'), findsNothing);
    expect(paths.any((p) => p.endsWith('/social/8')), true);
    await tester.pumpWidget(const SizedBox());
    user.dispose();
    visible.dispose();
    api.close();
  });

  testWidgets(
    'a refreshed card reconciles likes instead of retaining initial counts',
    (tester) async {
      Widget card(int likes) => MaterialApp(
        home: Scaffold(
          body: FeedCard(
            key: const ValueKey(1),
            post: {...post(1, 'Fixture'), 'likes': likes},
          ),
        ),
      );
      await tester.pumpWidget(card(1));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      await tester.pumpWidget(card(9));
      await tester.pump();
      expect(find.text('9'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    },
  );
}
