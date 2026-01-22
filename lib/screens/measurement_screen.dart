import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;

import '../models/measurement_model.dart';
import '../services/ar_service.dart';
import '../widgets/measurement_overlay.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  ARKitController? _arKitController;
  ARMeasurementService? _arService;
  final MeasurementSession _session = MeasurementSession(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
  );

  String _statusText = 'Tap to place first point';
  bool _isMetric = true;
  bool _showMeasurements = false;
  double? _liveDistance;
  List<ProjectedLine> _projectedLines = [];
  bool _hasSurface = false;
  
  // Timer for continuous distance updates
  Stream<void>? _trackingStream;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      setState(() {
        _statusText = 'Camera permission required';
      });
    }
  }

  void _onARKitViewCreated(ARKitController controller) {
    _arKitController = controller;

    // Initialize AR service
    _arService = ARMeasurementService(
      onMeasurementComplete: _onMeasurementComplete,
      onError: _onError,
      onLiveDistanceUpdate: _onLiveDistanceUpdate,
    );
    _arService!.initializeController(controller);

    // Disable tap handler - we'll use the plus button instead
    controller.onARTap = null;

    // Start continuous tracking for real-time distance and line projections
    _startContinuousTracking();
  }

  void _onMeasurementComplete(MeasurementLine line) {
    setState(() {
      _session.addMeasurement(line);
      _statusText = 'Tap to place first point';
      _liveDistance = null;
    });

    // Show green success popup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Measured: ${line.getFormattedDistance(metric: _isMetric)}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onError(String error) {
    setState(() {
      _statusText = error;
    });

    // Show red error popup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onLiveDistanceUpdate(double distance) {
    setState(() {
      _liveDistance = distance;
    });
  }

  void _startContinuousTracking() {
    // Update projections and distance 30 times per second
    _trackingStream = Stream.periodic(const Duration(milliseconds: 33), (_) {});
    _trackingStream!.listen((_) async {
      if (_arService == null || _arKitController == null) return;

      // 1. Check for surface at center and Update live distance if measuring
      // Use smoothed position for live tracking to reduce jitter
      final worldPos = await _arService!.getSmoothedWorldPosition(0.5, 0.5);
      final hasSurface = worldPos != null;

      if (_arService?.isWaitingForSecondPoint == true) {
        // Use regular getWorldPosition for distance calculation (accuracy) 
        // but can use smoothed for live distance display to reduce flickering numbers
        final distancePos = await _arService!.getWorldPosition(0.5, 0.5);
        if (distancePos != null && _arService!.firstPendingPoint != null) {
          final distance = (distancePos - _arService!.firstPendingPoint!.position).length;
          _onLiveDistanceUpdate(distance);
        }
      }

      // 2. Project all existing measurements to screen space in parallel
      final List<ProjectedLine> newProjectedLines = [];

      // Create list of futures for parallel processing
      final List<Future<List<ProjectedLine>>> projectionFutures = _session.measurements.map((measurement) async {
        final List<ProjectedLine> measurementLines = [];
        
        final start = await _arService!.projectPoint(measurement.startPoint.position);
        final end = await _arService!.projectPoint(measurement.endPoint.position);

        if (start != null && end != null) {
          // Add main direct line only
          measurementLines.add(ProjectedLine(
            start: start,
            end: end,
            label: measurement.getFormattedDistance(metric: _isMetric),
          ));
        }
        
        return measurementLines;
      }).toList();

      // 3. Project currently pending line if exists
      if (_arService!.isWaitingForSecondPoint && _arService!.firstPendingPoint != null) {
        projectionFutures.add(() async {
          final List<ProjectedLine> pendingLines = [];
          final startPos = _arService!.firstPendingPoint!.position;
          
          // Get the current detected surface position at crosshair
          final currentWorldPos = await _arService!.getWorldPosition(0.5, 0.5);
          
          if (currentWorldPos != null) {
            // Project both points for the direct line
            final startScreen = await _arService!.projectPoint(startPos);
            final currentScreenPos = await _arService!.projectPoint(currentWorldPos);
            
            if (startScreen != null && currentScreenPos != null) {
              // 1. Direct line - show only this while pulling
              pendingLines.add(ProjectedLine(
                start: startScreen,
                end: currentScreenPos,
                label: '', // Main distance shown in status text at top
              ));
            }
          }
          return pendingLines;
        }());
      }

      // Wait for all projections simultaneously to reduce lag/drift
      final results = await Future.wait(projectionFutures);
      for (final lineList in results) {
        newProjectedLines.addAll(lineList);
      }

      if (mounted) {
        setState(() {
          _projectedLines = newProjectedLines;
          _hasSurface = hasSurface;
        });
      }
    });
  }

  void _clearAll() {
    setState(() {
      _session.clear();
      _statusText = 'Tap to place first point';
      _liveDistance = null;
      _projectedLines = [];
    });
    _arService?.clearAll();
  }

  void _undoLast() {
    if (_session.isNotEmpty) {
      setState(() {
        _session.removeLast();
        _statusText = _session.isEmpty ? 'Tap to place first point' : 'Measurement removed';
        _liveDistance = null;
      });
    }
  }

  void _toggleUnits() {
    setState(() {
      _isMetric = !_isMetric;
    });
  }

  void _toggleMeasurementsList() {
    setState(() {
      _showMeasurements = !_showMeasurements;
    });
  }

  String _getDisplayText() {
    if (_liveDistance != null && _arService?.isWaitingForSecondPoint == true) {
      // Show live distance while measuring
      if (_isMetric) {
        if (_liveDistance! < 1.0) {
          return '${(_liveDistance! * 100).toStringAsFixed(1)} cm';
        } else {
          return '${_liveDistance!.toStringAsFixed(2)} m';
        }
      } else {
        final inches = _liveDistance! * 39.3701;
        if (inches < 12) {
          return '${inches.toStringAsFixed(1)} in';
        } else {
          final feet = inches / 12;
          return '${feet.toStringAsFixed(2)} ft';
        }
      }
    }
    return _statusText;
  }




  // Capture point at screen center using the plus button
  Future<void> _capturePoint() async {
    if (_arService == null) return;

    // Use center of screen (0.5, 0.5)
    final position = await _arService!.getWorldPosition(0.5, 0.5);
    if (position != null) {
      _arService!.resetSmoothing(); // Reset for next measurement
      
      // Check if this will be the first point (before adding)
      final isFirstPoint = !_arService!.isWaitingForSecondPoint;
      
      // Add the point to the service
      _arService!.addPointFromVector(position);

      // Update status based on state AFTER adding point
      if (_arService!.isWaitingForSecondPoint) {
        setState(() {
          _statusText = 'Move to end point';
          _liveDistance = null; // Reset live distance for fresh start
        });
      }
    } else {
      _onError('No surface detected.');
    }
  }

  @override
  void dispose() {
    _arService?.dispose();
    _arKitController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ARKit View
          ARKitSceneView(
            onARKitViewCreated: _onARKitViewCreated,
            enableTapRecognizer: false,
            configuration: ARKitConfiguration.worldTracking,
            worldAlignment: ARWorldAlignment.gravity,
            planeDetection: ARPlaneDetection.horizontalAndVertical,
          ),

          // Measurement overlay (crosshair and projected lines)
          IgnorePointer(
            child: MeasurementOverlay(
              showCrosshair: true,
              statusText: _getDisplayText(),
              isTracking: _arService?.isWaitingForSecondPoint ?? false,
              hasSurface: _hasSurface,
              lines: _projectedLines,
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),

                    // Unit toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: GestureDetector(
                        onTap: _toggleUnits,
                        child: Text(
                          _isMetric ? 'Metric' : 'Imperial',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Measurements list (if visible)
                  if (_showMeasurements && _session.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _session.count,
                        itemBuilder: (context, index) {
                          final measurement = _session.measurements[index];
                          return MeasurementCard(
                            distance: measurement.getFormattedDistance(
                              metric: _isMetric,
                            ),
                            index: index,
                            onDelete: () {
                              setState(() {
                                _session.measurements.removeAt(index);
                              });
                            },
                          );
                        },
                      ),
                    ),

                  // Control buttons at very bottom
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Clear button
                        _buildControlButton(
                          icon: Icons.delete_outline,
                          label: 'Clear',
                          onPressed: _session.isNotEmpty ? _clearAll : null,
                        ),

                        // Undo button
                        _buildControlButton(
                          icon: Icons.undo,
                          label: 'Undo',
                          onPressed: _session.isNotEmpty ? _undoLast : null,
                        ),

                        // List button
                        _buildControlButton(
                          icon: _showMeasurements ? Icons.visibility_off : Icons.list,
                          label: _showMeasurements ? 'Hide' : 'List',
                          onPressed: _session.isNotEmpty ? _toggleMeasurementsList : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Plus button higher up (iOS Measure app style)
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _capturePoint,
                    customBorder: const CircleBorder(),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        size: 40,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : Colors.white54,
              shape: BoxShape.circle,
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              icon: Icon(icon, color: Colors.black87),
              onPressed: onPressed,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
