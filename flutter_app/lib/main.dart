import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/course_detail_page.dart';
import 'pages/course_list_page.dart';
import 'state/course_catalog.dart';

void main() => runApp(const FlmApp());

class FlmApp extends StatelessWidget {
  const FlmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CourseCatalog()..load(),
      child: MaterialApp(
        title: 'Môn học FLM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
          useMaterial3: true,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Môn học FLM')),
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          CourseListPage(),
          _IntegrationPage(
            icon: Icons.hub_outlined,
            title: 'Sơ đồ môn học',
            message: 'Màn hình Graph View sẽ được tích hợp tại đây.',
          ),
          _IntegrationPage(
            icon: Icons.chat_bubble_outline,
            title: 'Trợ lý AI',
            message: 'Màn hình Chat AI sẽ được tích hợp tại đây.',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Môn học',
          ),
          NavigationDestination(icon: Icon(Icons.hub_outlined), label: 'Sơ đồ'),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Trợ lý AI',
          ),
        ],
      ),
    );
  }
}

class _IntegrationPage extends StatelessWidget {
  const _IntegrationPage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
