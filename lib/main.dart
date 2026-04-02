import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart'; 

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
      // Error ආපු වැරදි parameters මෙතැනින් ඉවත් කර ඇත
      theme: appTheme.copyWith(
        // අයිකන වලට කිසිදු බලපෑමක් නොකර අකුරු වලට පමණක් SinhalaFont එක ලබා දීම
        textTheme: appTheme.textTheme.apply(fontFamily: 'SinhalaFont'),
        primaryTextTheme: appTheme.primaryTextTheme.apply(fontFamily: 'SinhalaFont'),
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(), 
    );
  }
}