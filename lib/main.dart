import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart'; // Imported the new Login Screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const TeaCollectionApp());
}

class TeaCollectionApp extends StatelessWidget {
  const TeaCollectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tea Collection App',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(), // Changed starting screen to LoginScreen
    );
  }
}