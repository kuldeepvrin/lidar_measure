import 'package:flutter/material.dart';

/// Smooths a stream of 2D coordinates using Exponential Moving Average (EMA).
class CoordinateSmoother {
  final double smoothingFactor;
  Offset? _lastOffset;

  CoordinateSmoother({this.smoothingFactor = 0.3});

  /// Processes a raw offset and returns a smoothed version.
  Offset smooth(Offset raw) {
    if (_lastOffset == null) {
      _lastOffset = raw;
      return raw;
    }

    final smoothedX = _lastOffset!.dx + (raw.dx - _lastOffset!.dx) * smoothingFactor;
    final smoothedY = _lastOffset!.dy + (raw.dy - _lastOffset!.dy) * smoothingFactor;
    
    _lastOffset = Offset(smoothedX, smoothedY);
    return _lastOffset!;
  }

  /// Resets the smoother state.
  void reset() {
    _lastOffset = null;
  }
}
