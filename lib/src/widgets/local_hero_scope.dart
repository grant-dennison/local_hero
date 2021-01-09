import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:local_hero/src/rendering/controller.dart';
import 'package:local_hero/src/widgets/local_hero.dart';
import 'package:local_hero/src/widgets/local_hero_layer.dart';

// ignore_for_file: public_member_api_docs

/// A widget under which you can create [LocalHero] widgets.
class LocalHeroScope extends StatefulWidget {
  /// Creates a [LocalHeroScope].
  /// All local hero animations under this widget, will have the specified
  /// [duration], [curve], and [createRectTween].
  const LocalHeroScope({
    Key key,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.linear,
    this.createRectTween = _defaultCreateTweenRect,
    @required this.child,
  })  : assert(child != null),
        assert(duration != null),
        assert(curve != null),
        assert(createRectTween != null),
        super(key: key);

  /// The duration of the animation.
  final Duration duration;

  /// The curve for the hero animation.
  final Curve curve;

  /// Defines how the destination hero's bounds change as it flies from the
  /// starting position to the destination position.
  ///
  /// The default value creates a [MaterialRectArcTween].
  final CreateRectTween createRectTween;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.child}
  final Widget child;

  @override
  _LocalHeroScopeState createState() => _LocalHeroScopeState();
}

class _LocalHeroScopeState extends State<LocalHeroScope>
    with TickerProviderStateMixin
    implements LocalHeroScopeState {
  final Map<Object, _LocalHeroTracker> trackers = <Object, _LocalHeroTracker>{};

  @override
  LocalHeroController track(BuildContext context, LocalHero localHero) {
    final _LocalHeroTracker tracker = trackers.putIfAbsent(
      localHero.tag,
      () => createTracker(localHero.tag),
    );
    tracker.trackedList.add(_TrackedLocalHero(
      localHero: localHero,
      context: context,
    ));
    return tracker.controller;
  }

  _LocalHeroTracker createTracker(Object tag) {
    final LocalHeroController controller = LocalHeroController(
      duration: widget.duration,
      createRectTween: widget.createRectTween,
      curve: widget.curve,
      tag: tag,
      vsync: this,
    );

    final _LocalHeroTracker tracker = _LocalHeroTracker(
      controller: controller,
    );

    tracker.addOverlay(context);
    return tracker;
  }

  @override
  void untrack(LocalHero localHero) {
    final _LocalHeroTracker tracker = trackers[localHero.tag];
    if (tracker != null) {
      tracker.trackedList
          .removeWhere((element) => element.localHero == localHero);
      if (tracker.trackedList.isEmpty) {
        trackers.remove(localHero.tag);
        disposeTracker(tracker);
      }
    }
  }

  @override
  void dispose() {
    trackers.values.forEach(disposeTracker);
    super.dispose();
  }

  void disposeTracker(_LocalHeroTracker tracker) {
    tracker.controller.dispose();
    tracker.removeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedLocalHeroScopeState(
      state: this,
      child: widget.child,
    );
  }
}

class _TrackedLocalHero {
  LocalHero localHero;
  BuildContext context;

  _TrackedLocalHero({this.localHero, this.context});
}

abstract class LocalHeroScopeState {
  LocalHeroController track(BuildContext context, LocalHero localHero);

  void untrack(LocalHero localHero);
}

class _LocalHeroTracker {
  _LocalHeroTracker({
    @required this.controller,
  }) : assert(controller != null) {
    _overlayEntry = OverlayEntry(
      builder: _buildOverlayWidget,
    );
  }

  OverlayEntry _overlayEntry;
  final LocalHeroController controller;
  final List<_TrackedLocalHero> trackedList = [];

  bool _removeRequested = false;
  bool _overlayInserted = false;

  Widget _buildOverlayWidget(BuildContext context) {
    return LocalHeroFollower(
      controller: controller,
      child: _buildShuttle(context),
    );
  }

  Widget _buildShuttle(BuildContext context) {
    assert(trackedList.isNotEmpty);
    final firstTracked = trackedList[0];
    final localHero = firstTracked.localHero;
    return localHero.flightShuttleBuilder?.call(
          firstTracked.context,
          controller.view,
          localHero.child,
        ) ??
        localHero.child;
  }

  void addOverlay(BuildContext context) {
    // TODO: Introduce an Overlay at scope instead of relying on Navigator Overlay
    final OverlayState overlayState = Overlay.of(context);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_removeRequested) {
        overlayState.insert(_overlayEntry);
        _overlayInserted = true;
      }
    });
  }

  void removeOverlay() {
    _removeRequested = true;
    if (_overlayInserted) {
      _overlayEntry.remove();
    }
  }
}

class _InheritedLocalHeroScopeState extends InheritedWidget {
  const _InheritedLocalHeroScopeState({
    Key key,
    @required this.state,
    @required Widget child,
  })  : assert(state != null),
        assert(child != null),
        super(key: key, child: child);

  final LocalHeroScopeState state;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;
}

extension BuildContextExtensions on BuildContext {
  T getInheritedWidget<T extends InheritedWidget>() {
    final InheritedElement elem = getElementForInheritedWidgetOfExactType<T>();
    return elem?.widget as T;
  }

  LocalHeroScopeState getLocalHeroScopeState() {
    final inheritedState = getInheritedWidget<_InheritedLocalHeroScopeState>();
    assert(() {
      if (inheritedState == null) {
        throw FlutterError('No LocalHeroScope for a LocalHero\n'
            'When creating a LocalHero, you must ensure that there\n'
            'is a LocalHeroScope above the LocalHero.\n');
      }
      return true;
    }());

    return inheritedState.state;
  }
}

RectTween _defaultCreateTweenRect(Rect begin, Rect end) {
  return MaterialRectArcTween(begin: begin, end: end);
}
