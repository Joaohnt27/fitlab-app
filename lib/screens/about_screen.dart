import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "SOBRE O PROJETO",
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Center(
              child: SizedBox(
                height: 100,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título e Versão
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFF06B6D4)],
              ).createShader(bounds),
              child: const Text(
                "FITLAB",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Versão 1.3.0",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 40),

            // Card - Objetivo do App
            _buildAboutCard(
              title: "OBJETIVO",
              content:
                  "O FitLab é um aplicativo de acompanhamento dinâmico para praticantes de corrida e caminhada, integrando em um sistema unificado, as necessidades do atleta e as diretrizes do treinador, utilizando inteligência artificial para personalização dos treinos e mecânicas de gamificação com a finalidade de aumentar a retenção e motivação dos usuários.",
            ),

            const SizedBox(height: 30),

            // Seção de Desenvolvedores 
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "DESENVOLVEDORES",
                style: TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDeveloperProfile(
                    name: "Arthur Vital\nFontana",
                    ra: "RA: 839832",
                    imagePath: 'assets/images/arthur.jpeg', 
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDeveloperProfile(
                    name: "João Henrique\nNazar Tavares",
                    ra: "RA: 839463",
                    imagePath: 'assets/images/joao.jpeg', 
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Card Institucional (UNAERP / Orientador)
            _buildInstitutionalCard(),

            const SizedBox(height: 40),
            const Divider(color: Colors.white10),
            const SizedBox(height: 20),
            const Text(
              "© 2026 TechIB. Todos os direitos reservados.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Card Textual Padrão (usado para o objetivo)
  Widget _buildAboutCard({required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF06B6D4),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperProfile({
    required String name,
    required String ra,
    String? imagePath,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: const Color(0xFF121212),
              backgroundImage: imagePath != null ? AssetImage(imagePath) : null,
              child: imagePath == null
                  ? const Icon(Icons.person, color: Colors.white38, size: 35)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ra,
              style: const TextStyle(
                color: Color(0xFF06B6D4),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "INFORMAÇÕES ACADÊMICAS",
            style: TextStyle(
              color: Color(0xFF06B6D4),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.account_balance,
            "Instituição",
            "Universidade de Ribeirão Preto - UNAERP",
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Colors.white10),
          ),
          _buildInfoRow(
            Icons.menu_book,
            "Disciplina",
            "Projeto de Conclusão de Curso I e II",
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Colors.white10),
          ),
          _buildInfoRow(
            Icons.school,
            "Orientador",
            "Prof. Dr. Rodrigo de Oliveira Plotze",
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
