import 'package:flutter/material.dart';
import 'package:kockatoos_nova_ai_chatbot/kockatoos_nova_ai_chatbot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // LIVE BACKEND CONFIGURATION
  // Replace 'https://chatbot.kockatoos.com' with your live backend server URL
  // Replace 'YOUR_LIVE_PUBLIC_KEY' with your workspace public key from admin
  // ---------------------------------------------------------------------------
  const String liveBackendUrl = 'http://10.0.2.2:8000';
  const String workspacePublicKey = 'kc_3XA9M9ccS3iy3Et8b8TJ6vltrRmlYOxA';

  // Initialize Nova SDK with Live Backend Server & Admin Panel Config
  await Nova.initialize(
    config: const NovaConfig(
      apiKey: workspacePublicKey,
      baseUrl: liveBackendUrl,
      logLevel: NovaLogLevel.debug,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kockatoos Nova Chatbot Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF05A2B)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kockatoos Nova Chatbot App'),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 64, color: Color(0xFFF05A2B)),
                  SizedBox(height: 16),
                  Text(
                    'Welcome to Kockatoos Nova SDK Demo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the floating action button below or switch to the Chat tab to interact with the live native Flutter chat widget.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          NovaChatView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat View'),
        ],
      ),
      floatingActionButton:
          _selectedIndex == 0 ? const NovaFloatingButton() : null,
    );
  }
}
