import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitlab_mobile2/models/feed_timeline.dart';
import 'package:fitlab_mobile2/services/session_api.dart';

void main() {
  Map<String, dynamic> post(int id) => {'id': id, 'texto': 'Fixture $id'};
  http.Response response(List<dynamic> posts) =>
      http.Response(jsonEncode(posts), 200);
  FeedTimeline model(Future<http.Response> Function(http.Request) handler) =>
      FeedTimeline(
        userId: 7,
        api: SessionApi(
          token: 'fixture',
          baseUrl: 'http://local.invalid/api',
          client: MockClient(handler),
        ),
      );

  test(
    'refresh restarts pagination and subsequent pages do not duplicate posts',
    () async {
      final pages = <String>[];
      final feed = model((r) async {
        expect(r.headers['Authorization'], 'Bearer fixture');
        pages.add(r.url.queryParameters['page']!);
        return response(
          pages.last == '0'
              ? List.generate(10, (i) => post(i + 1))
              : [post(10), post(11)],
        );
      });
      addTearDown(feed.dispose);
      await feed.refresh();
      await feed.loadMore();
      expect(feed.posts.map((p) => p['id']), List.generate(11, (i) => i + 1));
      expect(feed.hasMore, false);
      await feed.refresh();
      await feed.loadMore();
      expect(pages, ['0', '1', '0', '1']);
      expect(feed.posts.length, 11);
    },
  );

  test('failed refresh retains loaded posts and permits retry', () async {
    var fail = false;
    final feed = model((r) async {
      if (fail) throw http.ClientException('Fixture without network');
      return response([post(1)]);
    });
    addTearDown(feed.dispose);
    await feed.refresh();
    fail = true;
    await feed.refresh();
    expect(feed.posts.single['id'], 1);
    expect(feed.error, isNotNull);
    expect(feed.loading, false);
    fail = false;
    await feed.refresh();
    expect(feed.error, isNull);
  });

  test(
    'late pagination response cannot append stale posts after refresh',
    () async {
      final page = Completer<http.Response>();
      var version = 0;
      final feed = model((r) async {
        if (r.url.queryParameters['page'] == '1') return page.future;
        return response(
          version == 0 ? List.generate(10, (i) => post(i + 1)) : [post(99)],
        );
      });
      addTearDown(feed.dispose);
      await feed.refresh();
      final more = feed.loadMore();
      version = 1;
      await feed.refresh();
      page.complete(response([post(11)]));
      await more;
      expect(feed.posts.map((p) => p['id']), [99]);
    },
  );

  test(
    'publication during request queues a fresh read with no parallel duplicate requests',
    () async {
      final initial = Completer<http.Response>();
      var calls = 0;
      final feed = model(
        (r) async => ++calls == 1 ? initial.future : response([post(2)]),
      );
      addTearDown(feed.dispose);
      final first = feed.refresh();
      await Future<void>.delayed(Duration.zero);
      final second = feed.refresh();
      expect(calls, 1);
      initial.complete(response([post(1)]));
      await Future.wait([first, second]);
      expect(calls, 2);
      expect(feed.posts.single['id'], 2);
    },
  );

  test(
    'disposing an in-flight request prevents notifications and state writes',
    () async {
      final pending = Completer<http.Response>();
      var notifications = 0;
      final feed = model((r) => pending.future)
        ..addListener(() => notifications++);
      final operation = feed.refresh();
      expect(notifications, 1);
      feed.dispose();
      pending.complete(response([post(1)]));
      await operation;
      expect(notifications, 1);
    },
  );
}
