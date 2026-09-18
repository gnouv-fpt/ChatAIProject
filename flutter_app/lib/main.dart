import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/chat/providers/chat_provider.dart';
import 'features/chat/views/chat_screen.dart';
import 'features/graph/views/graph_view_screen.dart';
import 'pages/course_detail_page.dart';
import 'pages/course_list_page.dart';
import 'state/course_catalog.dart';

void main() => runApp(const FlmApp());

class FlmApp extends StatelessWidget {
  const FlmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourseCatalog()..load()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Hệ thống Môn học & Trợ lý Chat AI (FLM)',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1976D2),
            primary: const Color(0xFF1976D2),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const AppShell(),
        onGenerateRoute: (settings) {
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri != null &&
              uri.pathSegments.length == 2 &&
              uri.pathSegments.first == 'courses') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => CourseDetailPage(code: uri.pathSegments.last),
            );
          }
          return null;
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  final List<String> _titles = const [
    'Danh sách Môn học FLM',
    'Sơ đồ Đồ thị Môn học (Obsidian Graph)',
    'Trợ lý AI FLM (RAG)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          CourseListPage(),
          GraphViewScreen(),
          ChatScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Môn học',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: 'Sơ đồ',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Trợ lý AI',
          ),
        ],
      ),
    );
  }
}
