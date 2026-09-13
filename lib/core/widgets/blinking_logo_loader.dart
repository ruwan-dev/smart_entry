import 'package:flutter/material.dart';

class BlinkingLogoLoader extends StatefulWidget {
  final double size;
  final String imagePath;

  const BlinkingLogoLoader({
    super.key,
    this.size = 24.0,
    this.imagePath = 'assets/custom_loader.png',
  });

  @override
  State<BlinkingLogoLoader> createState() => _BlinkingLogoLoaderState();
}

class _BlinkingLogoLoaderState extends State<BlinkingLogoLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(opacity: _opacityAnimation.value, child: child);
      },
      child: Image.asset(
        widget.imagePath,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => FlutterLogo(
          size: widget.size,
        ),
      ),
    );
  }
}
