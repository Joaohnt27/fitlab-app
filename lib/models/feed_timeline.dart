import 'package:flutter/foundation.dart';
import '../services/session_api.dart';

// Paginação do feed com descarte de respostas anteriores a uma atualização
class FeedTimeline extends ChangeNotifier {
  final SessionApi api;
  final int userId;
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String? error;
  int _nextPage = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _refreshAgain = false;
  Future<void>? _refreshing;

  FeedTimeline({required this.api, required this.userId});

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  List<Map<String, dynamic>> _read(dynamic value) {
    if (value is! List) throw const FormatException('Feed inválido.');
    final result = <Map<String, dynamic>>[];
    final ids = <int>{};
    for (final post in value) {
      if (post is! Map || post['id'] is! int) {
        throw const FormatException('Postagem inválida.');
      }
      if (ids.add(post['id'] as int)) {
        result.add(Map<String, dynamic>.from(post));
      }
    }
    return result;
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_refreshing != null) {
      _refreshAgain = true;
      return _refreshing!;
    }
    _refreshing = _refresh().whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  Future<void> _refresh() async {
    ++_generation;
    loading = posts.isEmpty;
    error = null;
    _changed();
    do {
      _refreshAgain = false;
      try {
        final raw = await api.get('/feed/social/$userId?page=0');
        final data = _read(raw);
        if (_disposed) return;
        if (!_refreshAgain) {
          posts = data;
          _nextPage = 1;
          hasMore = (raw as List).length >= 10;
          error = null;
        }
      } catch (_) {
        if (!_disposed) {
          error = 'Não foi possível atualizar o feed. Tente novamente.';
        }
      }
    } while (!_disposed && _refreshAgain);
    if (_disposed) return;
    loading = false;
    _changed();
  }

  Future<void> loadMore() async {
    if (_disposed || loadingMore || !hasMore || _refreshing != null) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    _changed();
    try {
      final raw = await api.get('/feed/social/$userId?page=$_nextPage');
      final data = _read(raw);
      if (_disposed || generation != _generation) return;
      final ids = posts.map((p) => p['id']).toSet();
      posts = [...posts, ...data.where((p) => ids.add(p['id']))];
      ++_nextPage;
      hasMore = (raw as List).length >= 10;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = 'Não foi possível carregar mais posts. Tente novamente.';
      }
    } finally {
      if (!_disposed) {
        loadingMore = false;
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
