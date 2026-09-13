import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  }) : super(key: key);

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _colorAnimation = ColorTween(begin: const Color(0xFFE5E7EB), end: const Color(0xFFF3F4F6)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _colorAnimation.value,
          borderRadius: widget.shape == BoxShape.circle ? null : BorderRadius.circular(widget.borderRadius),
          shape: widget.shape,
        ),
      ),
    );
  }
}
