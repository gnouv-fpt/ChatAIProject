import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/chat/views/chat_screen.dart';

void main() {
  runApp(const FlmObsidianApp());
}

class FlmObsidianApp extends StatelessWidget {
  const FlmObsidianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'FLM Obsidian & Chat AI System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1976D2),
            primary: const Color(0xFF1976D2),
          ),
          fontFamily: 'Roboto',
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
