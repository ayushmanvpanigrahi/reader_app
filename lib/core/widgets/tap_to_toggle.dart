import 'package:flutter/material.dart';

const double _maxTapDistance = 12;
const int _maxTapDurationMs = 350;

/// Wraps [child] with a raw pointer [Listener] that fires [onTap] on a clean
/// single tap, bypassing the gesture arena entirely.
///
/// PDF and EPUB viewers run their own scrolling/panning/zooming engines that
/// absorb every gesture, so a [GestureDetector] wrapping them never wins the
/// arena. Listening to raw pointer events detects taps without competing and
/// does not interfere with the viewer's own gestures (scrolls, flips, pinches)
/// because those move the pointer more than [maxTapDistance].
class TapToToggle extends StatefulWidget {
  const TapToToggle({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<TapToToggle> createState() => _TapToToggleState();
}

class _TapToToggleState extends State<TapToToggle> {
  final Map<int, Offset> _downPositions = {};
  final Map<int, int> _downTimes = {};

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _downPositions[event.pointer] = event.position;
        _downTimes[event.pointer] = event.timeStamp.inMilliseconds;
      },
      onPointerUp: (event) {
        final start = _downPositions.remove(event.pointer);
        final startTime = _downTimes.remove(event.pointer);
        if (start == null || startTime == null || _downPositions.isNotEmpty) {
          // Missing start or other fingers still down (pinch) - not a tap.
          return;
        }
        final distance = (event.position - start).distance;
        final elapsed = event.timeStamp.inMilliseconds - startTime;
        if (distance < _maxTapDistance && elapsed < _maxTapDurationMs) {
          widget.onTap();
        }
      },
      onPointerCancel: (event) {
        _downPositions.remove(event.pointer);
        _downTimes.remove(event.pointer);
      },
      child: widget.child,
    );
  }
}
