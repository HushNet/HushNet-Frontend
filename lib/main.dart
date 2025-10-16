import 'package:flutter/material.dart';
import 'package:hushnet_frontend/screens/onboarding.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final keyProvider = KeyProvider();

  runApp(const HushNetApp());
}

class HushNetApp extends StatelessWidget {
  const HushNetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: hushNetTheme,
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return const OnboardingScreen();
  }
}
