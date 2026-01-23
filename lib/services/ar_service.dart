import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../models/measurement_model.dart';

/// Service to manage ARKit session and handle LiDAR measurements
class ARMeasurementService {
  ARKitController? _controller;
  final List<MeasurementPoint> _pendingPoints = [];
  final Function(MeasurementLine)? onMeasurementComplete;
  final Function(String)? onError;
  final Function(double)? onLiveDistanceUpdate;

  ARMeasurementService({
    this.onMeasurementComplete,
    this.onError,
    this.onLiveDistanceUpdate,
  });

  /// Initialize ARKit controller
  void initializeController(ARKitController controller) {
    _controller = controller;
    // Tap handler disabled - using plus button for point capture
  }



  /// Add a measurement point from a 3D vector position
  void addPointFromVector(vm.Vector3 position) {
    // Create a measurement point from the position
    // Note: We store the 3D position directly. The stability comes from
    // using high-quality hit tests and removing 2D smoothing artifacts.
    final point = MeasurementPoint(
      position: position,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      anchorName: null, // ARKit plugin doesn't support custom anchors
    );

    _pendingPoints.add(point);

    // If we have two points, create a measurement line
    if (_pendingPoints.length == 2) {
      final line = MeasurementLine(
        startPoint: _pendingPoints[0],
        endPoint: _pendingPoints[1],
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Notify callback
      onMeasurementComplete?.call(line);

      // Clear pending points for next measurement
      _pendingPoints.clear();
    }
  }

  /// Projects a 3D world position to 2D screen coordinates
  Future<Offset?> projectPoint(vm.Vector3 position) async {
    if (_controller == null) return null;
    try {
      final projected = await _controller!.projectPoint(position);
      if (projected == null) return null;
      return Offset(projected.x, projected.y);
    } catch (e) {
      return null;
    }
  }





  /// Get hit result at normalized screen position (0.0 to 1.0)
  /// Uses multiple hit test types for better accuracy
  Future<vm.Vector3?> getWorldPosition(double x, double y) async {
    if (_controller == null) return null;

    try {
      // Perform hit test with multiple types for better accuracy
      final results = await _controller!.performHitTest(
        x: x,
        y: y,
      );
      
      if (results.isEmpty) return null;

      ARKitTestResult? bestResult;
      
      // Ranking system for results:
      for (final result in results) {
        if (result.type == ARKitHitTestResultType.existingPlaneUsingExtent) {
          bestResult = result;
          break;
        }
      }
      
      if (bestResult == null) {
        for (final result in results) {
          if (result.type == ARKitHitTestResultType.existingPlane) {
            bestResult = result;
            break;
          }
        }
      }
      
      if (bestResult == null) {
        for (final result in results) {
          if (result.type == ARKitHitTestResultType.featurePoint) {
            bestResult = result;
            break;
          }
        }
      }

      if (bestResult == null) {
        for (final result in results) {
          if (result.type == ARKitHitTestResultType.estimatedHorizontalPlane ||
              result.type == ARKitHitTestResultType.estimatedVerticalPlane) {
            bestResult = result;
            break;
          }
        }
      }
      
      bestResult ??= results.first;
      
      return vm.Vector3(
        bestResult.worldTransform.getColumn(3).x,
        bestResult.worldTransform.getColumn(3).y,
        bestResult.worldTransform.getColumn(3).z,
      );
    } catch (e) {
      return null;
    }
  }

  // Buffer for rolling average smoothing
  final List<vm.Vector3> _hitBuffer = [];
  static const int _maxBufferSize = 3; // Reduced from 5 for better accuracy 

  /// Get smoothed hit result for live tracking
  /// Uses rolling average of recent hits to eliminate depth flicker
  Future<vm.Vector3?> getSmoothedWorldPosition(double x, double y) async {
    final newPos = await getWorldPosition(x, y);
    
    if (newPos == null) {
      if (_hitBuffer.isEmpty) return null;
      // If we lose tracking briefly, return the last stable average
      return _calculateAverage(_hitBuffer);
    }

    _hitBuffer.add(newPos);
    if (_hitBuffer.length > _maxBufferSize) {
      _hitBuffer.removeAt(0);
    }

    return _calculateAverage(_hitBuffer);
  }

  vm.Vector3 _calculateAverage(List<vm.Vector3> points) {
    if (points.isEmpty) return vm.Vector3.zero();
    final sum = vm.Vector3.zero();
    for (final p in points) {
      sum.add(p);
    }
    return sum / points.length.toDouble();
  }

  /// Reset smoothing state
  void resetSmoothing() {
    _hitBuffer.clear();
  }

  /// Calculate live distance from first point to current position
  Future<void> updateLiveDistance() async {
    if (_pendingPoints.isEmpty || _controller == null) return;

    // Get current position at screen center
    final currentPos = await getWorldPosition(0.5, 0.5);
    if (currentPos != null) {
      final distance = (currentPos - _pendingPoints[0].position).length;
      onLiveDistanceUpdate?.call(distance);
    }
  }

  /// Clear all AR nodes
  void clearAll() {
    _pendingPoints.clear();
  }

  /// Dispose resources
  void dispose() {
    clearAll();
    _controller?.dispose();
    _controller = null;
    _pendingPoints.clear();
  }

  /// Check if waiting for second point
  bool get isWaitingForSecondPoint => _pendingPoints.length == 1;

  /// Get pending point count
  int get pendingPointCount => _pendingPoints.length;

  /// Get first pending point if exists
  MeasurementPoint? get firstPendingPoint => 
      _pendingPoints.isNotEmpty ? _pendingPoints[0] : null;
}
