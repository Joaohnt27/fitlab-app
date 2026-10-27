import 'package:flutter/material.dart';
import '../models/app_data.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../config/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  int _feedRevision = 0;
  int get feedRevision => _feedRevision;

  void notificarFeedAtualizado() {
    ++_feedRevision;
    notifyListeners();
  }

  String? _token;
  String? get token => _token;

  final Map<String, bool> _prefsNotificacoes = {
    'reminders': true,
    'achievements': true,
    'ranking': false,
    'marketing': false,
  };

  Map<String, bool> get prefsNotificacoes => _prefsNotificacoes;

  UserModel? _usuarioLogado;
  UserModel? get usuarioLogado => _usuarioLogado;
  String get nome => _usuarioLogado?.nome ?? "Usuário";

  UserProvider() {
    _carregarSessaoLocal();
  }

  Future<void> _carregarSessaoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenSalvo = prefs.getString('auth_token');
    final userSalvo = prefs.getString('user_data');

    _prefsNotificacoes['reminders'] = prefs.getBool('pref_notif_reminders') ?? true;
    _prefsNotificacoes['run_alerts'] = prefs.getBool('pref_notif_run_alerts') ?? true;
    _prefsNotificacoes['achievements'] = prefs.getBool('pref_notif_achievements') ?? true;
    _prefsNotificacoes['ranking'] = prefs.getBool('pref_notif_ranking') ?? false;
    _prefsNotificacoes['marketing'] = prefs.getBool('pref_notif_marketing') ?? false;

    if (tokenSalvo != null && userSalvo != null) {
      _token = tokenSalvo;
      _usuarioLogado = UserModel.fromJson(json.decode(userSalvo));
      notifyListeners(); 

      recarregarUsuario();
    }
  }

  // Helper para montar o Header com o Token 
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<bool> login(String email, String senha) async {
    try {
      final resultado = await _authService.fazerLogin(email, senha);

      if (resultado != null && resultado['usuario'] != null) {
        _usuarioLogado = resultado['usuario'];
        _token = resultado['token']; 

        // Salva os dados na memória física após o login com sucesso
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_data', json.encode(_usuarioLogado!.toJson()));

        notifyListeners();
        return true; 
      }
      return false; 
    } catch (e) {
      debugPrint("Erro no provedor durante o login: $e");
      return false;
    }
  }

  // Transforma o logout em async para limpar a memória física
  Future<void> logout() async {
    _usuarioLogado = null;
    _token = null; 

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');

    notifyListeners();
  }

  Future<void> atualizarPerfil({
    required String novoNome,
    String? novoAvatar,
    String? novaBio,
  }) async {
    if (_usuarioLogado == null) return;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/${_usuarioLogado!.id}/perfil',
    );

    final payload = {
      "nome": novoNome,
      "bio": novaBio ?? "",
      "avatar": novoAvatar ?? "🧪",
    };

    try {
      final response = await http.put(
        url,
        headers: _getHeaders(), 
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        _usuarioLogado!.nome = novoNome;
        if (novoAvatar != null) _usuarioLogado!.avatar = novoAvatar;
        if (novaBio != null) _usuarioLogado!.bio = novaBio;

        notifyListeners(); 
      } else {
        debugPrint("Erro na API ao salvar perfil: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Erro de conexão ao salvar perfil: $e");
    }
  }

  Future<String?> atualizarEmail(String novoEmail) async {
    if (_usuarioLogado == null) return "Usuário não logado";

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/${_usuarioLogado!.id}/email',
    );
    try {
      final response = await http.put(
        url,
        headers: _getHeaders(), 
        body: json.encode({"email": novoEmail}),
      );

      if (response.statusCode == 200) {
        _usuarioLogado!.email = novoEmail; 
        notifyListeners();
        return null; 
      } else {
        return response.body; 
      }
    } catch (e) {
      return "Erro de conexão. Tente novamente.";
    }
  }

  Future<String?> atualizarSenha(String senhaAtual, String novaSenha) async {
    if (_usuarioLogado == null) return "Usuário não logado";

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/${_usuarioLogado!.id}/senha',
    );
    try {
      final response = await http.put(
        url,
        headers: _getHeaders(), 
        body: json.encode({"senhaAtual": senhaAtual, "novaSenha": novaSenha}),
      );

      if (response.statusCode == 200) {
        return null; 
      } else {
        return response.body; 
      }
    } catch (e) {
      return "Erro de conexão. Tente novamente.";
    }
  }

  Future<bool> excluirConta() async {
    if (_usuarioLogado == null) return false;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/${_usuarioLogado!.id}',
    );
    try {
      final response = await http.delete(
        url,
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        _usuarioLogado = null; 
        _token = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Erro ao excluir conta: $e");
      return false;
    }
  }

  void atualizarPerfilCompleto(UserModel usuarioAtualizado) {
    _usuarioLogado = usuarioAtualizado;
    notifyListeners();
  }

  void mostrarAlertaBadge(BuildContext context, String nome, String icon) {
    // Mostra o alerta visual dentro do app 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF06B6D4)),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "NOVO BADGE DESBLOQUEADO!",
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Dispara a Notificação Local no Celular 
    final isAchievementAlertsEnabled = _prefsNotificacoes['achievements'] ?? true;
    
    if (isAchievementAlertsEnabled) {
      NotificationService().showNotification(
        title: 'Nova Conquista: $icon $nome',
        body: 'Sua biometria evoluiu no FitLab. Você ganhou uma nova badge!',
      );
    }
  }

  void atualizarEstatisticas({
    int? novosTerritorios,
    int? novasConquistas,
    int? novoStreak,
    int? novoRanking,
  }) {
    if (_usuarioLogado != null) {
      _usuarioLogado = _usuarioLogado!.copyWith(
        territorios: novosTerritorios,
        conquistas: novasConquistas,
        streak: novoStreak,
        ranking: novoRanking,
      );
      notifyListeners();
    }
  }

  Future<bool> salvarExperimentoUsuario(
    BuildContext context,
    String volume,
    String freq,
  ) async {
    if (_usuarioLogado == null) return false;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/${_usuarioLogado!.id}/experimentos',
    );

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(), // USANDO O HEADER COM TOKEN
        body: json.encode({"volume": volume, "frequencia": freq}),
      );

      if (response.statusCode == 200) {
        if (!context.mounted) return false;
        ganharXPeVerificarLevelUp(context, 10);

        int index = AppData.allBadges.indexWhere((b) => b.id == '1');
        if (index != -1 && !AppData.allBadges[index].isUnlocked) {
          AppData.allBadges[index] = AppData.allBadges[index].copyWith(
            isUnlocked: true,
          );
          _usuarioLogado = _usuarioLogado!.copyWith(
            conquistas: _usuarioLogado!.conquistas + 1,
          );
          mostrarAlertaBadge(
            context,
            AppData.allBadges[index].name,
            AppData.allBadges[index].icon,
          );
        }

        notifyListeners();
        return true; 
      } else {
        final erroResponse = json.decode(utf8.decode(response.bodyBytes));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                erroResponse['erro'] ?? 'Erro desconhecido no servidor.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return false; 
      }
    } catch (e) {
      debugPrint("❌ Erro fatal ao salvar experimento: $e");
      return false; 
    }
  }

  void verificarEAtualizarStreak() {
    if (_usuarioLogado == null) return;

    final agora = DateTime.now();
    final ultimoLogin = _usuarioLogado!.ultimoLogin;

    if (ultimoLogin == null) {
      _usuarioLogado = _usuarioLogado!.copyWith(streak: 1, ultimoLogin: agora);
    } else {
      final diferenca = agora.difference(ultimoLogin).inHours;

      if (diferenca > 48) {
        _usuarioLogado = _usuarioLogado!.copyWith(
          streak: 0,
          ultimoLogin: agora,
        );
      } else if (diferenca >= 24) {
        _usuarioLogado = _usuarioLogado!.copyWith(
          streak: _usuarioLogado!.streak + 1,
          ultimoLogin: agora,
        );
      }
    }
    notifyListeners();
  }

  void ganharXPeVerificarLevelUp(BuildContext context, int quantidade) {
    if (_usuarioLogado == null) return;

    final nivelAntes = AppData.getNivelByXP(_usuarioLogado!.xp);
    _usuarioLogado = _usuarioLogado!.copyWith(
      xp: _usuarioLogado!.xp + quantidade,
    );
    final nivelDepois = AppData.getNivelByXP(_usuarioLogado!.xp);

    if (nivelDepois['lv'] > nivelAntes['lv']) {
      _mostrarDialogoLevelUp(context, nivelDepois);
    }
    notifyListeners();
  }

  void _mostrarDialogoLevelUp(
    BuildContext context,
    Map<String, dynamic> novoNivel,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🚀 NOVO NÍVEL ALCANÇADO!",
                style: TextStyle(
                  color: Color(0xFF06B6D4),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Text(novoNivel['icon'], style: const TextStyle(fontSize: 80)),
              const SizedBox(height: 10),
              Text(
                "PATENTE: ${novoNivel['nome']}".toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Sua biometria evoluiu. Você desbloqueou novas capacidades no laboratório.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                  ),
                  child: const Text(
                    "CONTINUAR EVOLUÇÃO",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> recarregarUsuario() async {
    if (_usuarioLogado == null) return;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/usuarios/${_usuarioLogado!.id}',
    );
    try {
      final response = await http.get(
        url,
        headers: _getHeaders(), // USANDO O HEADER COM TOKEN
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _usuarioLogado = UserModel.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Erro no refresh silencioso: $e");
    }
  }

  Future<void> alternarNotificacao(String chave, bool valor) async {
    _prefsNotificacoes[chave] = valor;
    notifyListeners();
    
    // Salva na memória física do cllr 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_notif_$chave', valor);
  }
}