import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'firebase_options.dart';
import 'core/theme.dart';

// අලුතින් හදපු Splash Screen එක Import කරගන්න
import 'features/splash/splash_screen.dart'; 

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
      theme: appTheme.copyWith(
        textTheme: GoogleFonts.notoSansSinhalaTextTheme(appTheme.textTheme),
        primaryTextTheme: GoogleFonts.notoSansSinhalaTextTheme(appTheme.primaryTextTheme),
      ),
      debugShowCheckedModeBanner: false,
      
      // මුලින්ම LoginScreen එකට යන එක වෙනුවට SplashScreen එකට යවනවා
      home: const SplashScreen(), 
    );
  }
}