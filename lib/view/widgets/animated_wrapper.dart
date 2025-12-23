import 'package:flutter/material.dart';

enum AnimationType {
  flip,
  fadeIn,
  scale,
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  bounce,
  rotate,
}

class AnimatedWrapper extends StatefulWidget {
  final Widget child;
  final AnimationType animationType;
  final Duration duration;
  final Curve curve;
  final bool autoPlay;
  final VoidCallback? onAnimationComplete;

  const AnimatedWrapper({
    super.key,
    required this.child,
    required this.animationType,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeInOut,
    this.autoPlay = true,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedWrapper> createState() => AnimatedWrapperState();
}

class AnimatedWrapperState extends State<AnimatedWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Create animation based on type
    switch (widget.animationType) {
      case AnimationType.flip:
      case AnimationType.rotate:
        _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        break;
      case AnimationType.fadeIn:
        _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        break;
      case AnimationType.scale:
      case AnimationType.bounce:
        _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        break;
      case AnimationType.slideUp:
      case AnimationType.slideDown:
      case AnimationType.slideLeft:
      case AnimationType.slideRight:
        _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: widget.curve),
        );
        break;
    }

    // Listen for animation completion
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });

    // Auto play animation if enabled
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _buildAnimatedWidget();
      },
    );
  }

  Widget _buildAnimatedWidget() {
    switch (widget.animationType) {
      case AnimationType.flip:
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_animation.value * 2 * 3.14159),
          child: widget.child,
        );

      case AnimationType.fadeIn:
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );

      case AnimationType.scale:
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );

      case AnimationType.bounce:
        final bounceValue = _animation.value < 0.5
            ? 2 * _animation.value
            : 2 * (1 - _animation.value);
        return Transform.scale(
          scale: bounceValue,
          child: widget.child,
        );

      case AnimationType.slideUp:
        return Transform.translate(
          offset: Offset(0, (1 - _animation.value) * 100),
          child: Opacity(
            opacity: _animation.value,
            child: widget.child,
          ),
        );

      case AnimationType.slideDown:
        return Transform.translate(
          offset: Offset(0, (_animation.value - 1) * 100),
          child: Opacity(
            opacity: _animation.value,
            child: widget.child,
          ),
        );

      case AnimationType.slideLeft:
        return Transform.translate(
          offset: Offset((1 - _animation.value) * 100, 0),
          child: Opacity(
            opacity: _animation.value,
            child: widget.child,
          ),
        );

      case AnimationType.slideRight:
        return Transform.translate(
          offset: Offset((_animation.value - 1) * 100, 0),
          child: Opacity(
            opacity: _animation.value,
            child: widget.child,
          ),
        );

      case AnimationType.rotate:
        return Transform.rotate(
          angle: _animation.value * 2 * 3.14159,
          child: widget.child,
        );
    }
  }

  // Public method to trigger animation manually
  void play() {
    _controller.reset();
    _controller.forward();
  }

  void reverse() {
    _controller.reverse();
  }

  void reset() {
    _controller.reset();
  }
}

