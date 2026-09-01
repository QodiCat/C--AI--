import "package:flutter/material.dart";

import "../ai_stylist/presentation/ai_stylist_page.dart";
import "../profile/presentation/profile_page.dart";
import "../today_recommendation/presentation/today_recommendation_page.dart";
import "../wardrobe/presentation/wardrobe_page.dart";
import "../wear_history/presentation/wear_history_page.dart";

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _currentIndex = 0;

  final _pages = const [
    WardrobePage(),
    AiStylistPage(),
    TodayRecommendationPage(),
    WearHistoryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          SafeArea(child: IndexedStack(index: _currentIndex, children: _pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) {
          setState(() {
            _currentIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: "衣橱",
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: "AI搭配",
          ),
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: "推荐",
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: "记录",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "我的",
          ),
        ],
      ),
    );
  }
}
