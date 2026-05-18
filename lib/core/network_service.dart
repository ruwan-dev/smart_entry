import 'dart:async';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:lottie/lottie.dart'; 

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  bool hasInternet = true;
  bool isDialogShowing = false;
  StreamSubscription? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    
    _subscription = InternetConnection().onStatusChange.listen((InternetStatus status) {
      hasInternet = status == InternetStatus.connected;

      if (!hasInternet && !isDialogShowing) {
        _showNoInternetDialog();
      } else if (hasInternet && isDialogShowing) {
        _hideNoInternetDialog();
      }
    });
  }

  void _showNoInternetDialog() {
    if (_navigatorKey?.currentContext == null) return;
    
    isDialogShowing = true;
    showDialog(
      context: _navigatorKey!.currentContext!,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, 
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animation එකේ Size එක මෙතනින් ලොකු කරලා තියෙනවා 
                  Lottie.asset(
                    'assets/no_internet.json', 
                    width: 200,  // කලින් 120 තිබුණේ
                    height: 200, // කලින් 120 තිබුණේ
                    fit: BoxFit.contain, // cover වෙනුවට contain දැම්මාම කැපෙන්නේ නෑ
                    repeat: true, 
                  ),
                  const SizedBox(height: 15),
                  
                  const Text(
                    'Internet Connection Lost!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  
                  const Text(
                    'කරුණාකර ඔබගේ අන්තර්ජාල සම්බන්ධතාවය පරීක්ෂා කරන්න. යෙදුම භාවිතයට Internet පහසුකම අත්‍යවශ්‍ය වේ.',
                    style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  const Divider(color: Colors.black12, thickness: 1),
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Powered by OrbitView Innovations',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.headset_mic_rounded, size: 14, color: Colors.blueGrey.shade400),
                      const SizedBox(width: 6),
                      Text(
                        'Contact Support : 0719362659',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideNoInternetDialog() {
    if (_navigatorKey?.currentContext != null && isDialog