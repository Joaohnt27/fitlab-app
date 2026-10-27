import 'dart:ui';
import 'package:fitlab_mobile2/screens/community_screen.dart';
import 'package:fitlab_mobile2/screens/feed_screen.dart';
import 'package:fitlab_mobile2/screens/profile_screen.dart';
import 'package:fitlab_mobile2/screens/run_screen.dart';
import 'package:flutter/material.dart';
import 'workouts_screen.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const WorkoutsScreen(),
    const RunScreen(),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == 0 && index == 0) {
      context.read<UserProvider>().notificarFeedAtualizado();
    }
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _handleDrag(DragUpdateDetails details, double innerWidth) {
    double itemWidth = innerWidth / 5;
    int newIndex = (details.localPosition.dx / itemWidth).floor().clamp(0, 4);

    if (newIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double barWidth = screenWidth - 48; 
    double innerWidth = barWidth - 4.0; 
    double itemWidth = innerWidth / 5;
    double barHeight = 65.0; 
    // Cápsula mais gordinha para preencher o espaço do item
    double indicatorWidth = itemWidth * 0.95; 
    double indicatorHeight = 55.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBody: true, 
      
      body: IndexedStack(
        index: _selectedIndex,
        children: [FeedScreen(active: _selectedIndex == 0), ..._screens],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 30),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0), 
            child: Container(
              height: barHeight,
              width: barWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15), 
                    Colors.white.withOpacity(0.03), 
                  ],
                ),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25), 
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: -2,
                  )
                ],
              ),
              child: GestureDetector(
                onPanUpdate: (details) => _handleDrag(details, innerWidth),
                child: Stack(
                  alignment: Alignment.centerLeft, 
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: (_selectedIndex * itemWidth) + ((itemWidth - indicatorWidth) / 2) + 2.0,
                      width: indicatorWidth,
                      height: indicatorHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25), 
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    
                    Row(
                      children: [
                        _buildNavItem(0, Icons.home_rounded, 'Feed', itemWidth, barHeight),
                        _buildNavItem(1, Icons.fitness_center_rounded, 'Lab', itemWidth, barHeight),
                        _buildNavItem(2, Icons.play_arrow_rounded, 'Iniciar', itemWidth, barHeight),
                        _buildNavItem(3, Icons.people_alt_rounded, 'Social', itemWidth, barHeight),
                        _buildNavItem(4, Icons.person_rounded, 'Você', itemWidth, barHeight),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, double itemWidth, double barHeight) {
    final bool active = _selectedIndex == index;
    final color = active ? const Color(0xFF06B6D4) : Colors.white;

    return SizedBox(
      width: itemWidth,
      height: barHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, active ? -2 : 0, 0),
              child: Icon(icon, color: color, size: active ? 26 : 24),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                letterSpacing: 0.5,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}