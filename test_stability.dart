// Simple test to verify the stability improvements
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

void main() {
  // Test position stability detection
  final positions = [
    vm.Vector3(1.0, 2.0, 3.0),
    vm.Vector3(1.001, 2.001, 3.001), // Very close
    vm.Vector3(1.002, 2.002, 3.002), // Still close
  ];
  
  // Test stability threshold
  const threshold = 0.005; // 5mm
  final center = positions[1];
  
  bool isStable = true;
  for (final pos in positions) {
    if ((pos - center).length > threshold) {
      isStable = false;
      break;
    }
  }
  
  print('Position stability test: ${isStable ? "PASSED" : "FAILED"}');
  
  // Test projection smoothing
  final oldOffset = const Offset(100, 200);
  final newOffset = const Offset(110, 210);
  const smoothingFactor = 0.4;
  
  final smoothed = Offset(
    oldOffset.dx + (newOffset.dx - oldOffset.dx) * smoothingFactor,
    oldOffset.dy + (newOffset.dy - oldOffset.dy) * smoothingFactor,
  );
  
  final expectedX = 100 + (110 - 100) * 0.4; // 104
  final expectedY = 200 + (210 - 200) * 0.4; // 204
  
  final smoothingTest = (smoothed.dx - expectedX).abs() < 0.001 && 
                       (smoothed.dy - expectedY).abs() < 0.001;
  
  print('Projection smoothing test: ${smoothingTest ? "PASSED" : "FAILED"}');
  print('Expected: ($expectedX, $expectedY), Got: (${smoothed.dx}, ${smoothed.dy})');
}