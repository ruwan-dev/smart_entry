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

  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(true); 

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    
    _subscription = InternetConnection().onStatusChange.listen((InternetStatus status) {
      hasInternet = status == InternetStatus.connected;
      connectionStatus.value = hasInternet; 

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
        // Responsive ප්‍රමාණයන් ලබා ගැනීමට MediaQuery භාවිතා කිරීම
        final screenSize = MediaQuery.of(context).size;
        final bool isTablet = screenSize.width > 600;
        final double dialogWidth = isTablet ? 400 : screenSize.width * 0.85;

        return PopScope(
          canPop: false, 
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            backgroundColor: Colors.white,
            child: Container(
              width: dialogWidth,
              padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
              child: SingleChildScrollView( // කුඩා Screen වල overflow වීම වැළැක්වීමට
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animation එක screen size එකට අනුව වෙනස් වේ
                    Lottie.asset(
                      'assets/no_internet.json', 
                      width: isTablet ? 250 : screenSize.width * 0.45, 
                      height: isTablet ? 250 : screenSize.width * 0.45, 
                      fit: BoxFit.contain,
                      repeat: true, 
                    ),
                    const SizedBox(height: 15),
                    
                    Text(
                      'Internet Connection Lost!',
                      style: TextStyle(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      'කරුණාකර ඔබගේ අන්තර්ජාල සම්බන්ධතාවය පරීක්ෂා කරන්න. යෙදුම භාවිතයට Internet පහසුකම අත්‍යවශ්‍ය වේ.',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14, 
                        color: Colors.black87, 
                        height: 1.4
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    const Divider(color: Colors.black12, thickness: 1),
                    const SizedBox(height: 12),
                    
                    Text(
                      'Powered by OrbitView Innovations',
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.headset_mic_rounded, size: isTablet ? 16 : 14, color: Colors.blueGrey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          'Contact Support : 0719362659',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
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
          ),
        );
      },
    );
  }

  void _hideNoInternetDialog() {
    if (_navigatorKey?.currentContext != null && isDialogShowing) {
      Navigator.of(_navigatorKey!.currentContext!).pop();
      isDialogShowing = false;

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_navigatorKey?.currentContext != null) {
          ScaffoldMessenger.of(_navigatorKey!.currentContext!).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'අන්තර්ජාල සම්බන්ධතාවය යථා තත්ත්වයට පත් විය',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}