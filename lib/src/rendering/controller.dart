import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// ignore_for_file: public_member_api_docs

/// Signature for a function that takes two [Rect] instances and returns a
/// [RectTween] that transitions between them.
typedef RectTweenSupplier = Tween<Rect> Function(Rect begin, Rect end);

class LocalHeroController {
  LocalHeroController({
    @required TickerProvider vsync,
    @required Duration duration,
    @required this.curve,
    @required this.createRectTween,
    @required this.tag,
  })  : assert(createRectTween != null),
        assert(tag != null),
        link = LayerLink(),
        _controller = AnimationController(vsync: vsync, duration: duration) {
    _controller.addStatusListener(_onAnimationStatusChanged);
  }

  final Object tag;

  final LayerLink link;

  final AnimationController _controller;
  Animation<Rect> _animation;
  Animation<Matrix4> _matrixAnimation;
  Rect _lastRect;
  Matrix4 _lastMatrix;

  Curve curve;
  RectTweenSupplier createRectTween;

  Duration get duration => _controller.duration;
  set duration(Duration value) {
    _controller.duration = value;
  }

  bool get isAnimating => _isAnimating;
  bool _isAnimating = false;

  Animation<double> get view => _controller.view;

  Offset get linkedOffset => _animation?.value?.topLeft ?? _lastRect.topLeft;
  Matrix4 get linkedMatrix => _matrixAnimation?.value ?? Matrix4.identity();

  Size get linkedSize => _animation?.value?.size ?? _lastRect?.size;

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _isAnimating = false;
      _animation = null;
      _matrixAnimation = null;
      _controller.value = 0;
    }
  }

  // This seems to be invoked in an odd way.
  // Seems like it is relying on the relative paint order of different LocalHeros
  void animateIfNeeded(Rect rect, Matrix4 matrix) {
    if (_lastRect != null && _lastRect != rect) {
      final bool inAnimation = isAnimating;
      Rect from = Rect.fromLTWH(
        _lastRect.left - rect.left,
        _lastRect.top - rect.top,
        _lastRect.width,
        _lastRect.height,
      );
      Matrix4 fromMatrix = matrix
        ..invert()
        ..multiply(_lastMatrix);
      if (inAnimation) {
        // We need to recompute the from.
        final Rect currentRect = _animation.value;
        from = Rect.fromLTWH(
          currentRect.left + _lastRect.left - rect.left,
          currentRect.top + _lastRect.top - rect.top,
          currentRect.width,
          currentRect.height,
        );
      }
      _isAnimating = true;

      _animation = _controller.drive(CurveTween(curve: curve)).drive(
            createRectTween(
              from,
              Rect.fromLTWH(
                0,
                0,
                rect.width,
                rect.height,
              ),
            ),
          );
      _matrixAnimation = _controller
          .drive(CurveTween(curve: curve))
          .drive(Matrix4Tween(begin: fromMatrix, end: Matrix4.identity()));

      if (!inAnimation) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _controller.forward();
        });
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final Duration duration =
              _controller.duration * (1 - _controller.value);
          _controller.reset();
          _controller.animateTo(
            1,
            duration: duration,
          );
        });
      }
    }
    _lastRect = rect;
    _lastMatrix = matrix;
  }

  void dispose() {
    _controller.stop();
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
  }

  void addListener(VoidCallback listener) {
    _controller.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _controller.removeListener(listener);
  }

  void addStatusListener(AnimationStatusListener listener) {
    _controller.addStatusListener(listener);
  }

  void removeStatusListener(AnimationStatusListener listener) {
    _controller.removeStatusListener(listener);
  }
}
