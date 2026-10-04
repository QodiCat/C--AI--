import "package:flutter/material.dart";

import "../ai_stylist/presentation/ai_stylist_page.dart";
import "../profile/presentation/profile_page.dart";
import "../today_recommendation/presentation/today_recommendation_page.dart";
import "../wardrobe/presentation/wardrobe_page.dart";
import "../wear_history/presentation/wear_history_page.dart";
import "../outfits/presentation/my_outfits_page.dart";

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const WardrobePage(),
      const OutfitRecommendationPage(),
      const MyOutfitsPage(),
      const WearHistoryPage(),
      ProfilePage(onLogout: widget.onLogout),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
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
            label: "搭配推荐",
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: "我的搭配",
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

class OutfitRecommendationPage extends StatelessWidget {
  const OutfitRecommendationPage({super.key});
  @override
  Widget build(BuildContext context) => const DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(tabs: [Tab(text: "AI 搭配"), Tab(text: "今日推荐")]),
        Expanded(
            child: TabBarView(
                children: [AiStylistPage(), TodayRecommendationPage()])),
      ]));
}
