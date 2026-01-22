import 'package:vector_math/vector_math_64.dart';

/// Represents a single measurement point in 3D space
class MeasurementPoint {
  final Vector3 position;
  final DateTime timestamp;
  final String id;

  MeasurementPoint({
    required this.position,
    required this.id,
  }) : timestamp = DateTime.now();

  @override
  String toString() => 'Point(${position.x.toStringAsFixed(2)}, ${position.y.toStringAsFixed(2)}, ${position.z.toStringAsFixed(2)})';
}

/// Represents a measurement line between two points
class MeasurementLine {
  final MeasurementPoint startPoint;
  final MeasurementPoint endPoint;
  final String id;

  MeasurementLine({
    required this.startPoint,
    required this.endPoint,
    required this.id,
  });

  /// Calculate the distance between the two points in meters
  double get distance {
    final dx = endPoint.position.x - startPoint.position.x;
    final dy = endPoint.position.y - startPoint.position.y;
    final dz = endPoint.position.z - startPoint.position.z;
    return Vector3(dx, dy, dz).length;
  }

  /// Get distance in centimeters
  double get distanceInCm => distance * 100;

  /// Get distance in inches
  double get distanceInInches => distance * 39.3701;

  /// Get formatted distance string
  String getFormattedDistance({bool metric = true}) {
    if (metric) {
      if (distance < 1.0) {
        return '${distanceInCm.toStringAsFixed(1)} cm';
      } else {
        return '${distance.toStringAsFixed(2)} m';
      }
    } else {
      if (distance < 0.3048) { // Less than 1 foot
        return '${distanceInInches.toStringAsFixed(1)} in';
      } else {
        final feet = distance * 3.28084;
        return '${feet.toStringAsFixed(2)} ft';
      }
    }
  }

  @override
  String toString() => 'Line: ${getFormattedDistance()}';
}

/// Represents a measurement session with multiple measurements
class MeasurementSession {
  final List<MeasurementLine> measurements;
  final DateTime createdAt;
  final String id;

  MeasurementSession({
    List<MeasurementLine>? measurements,
    required this.id,
  })  : measurements = measurements ?? [],
        createdAt = DateTime.now();

  void addMeasurement(MeasurementLine line) {
    measurements.add(line);
  }

  void removeLast() {
    if (measurements.isNotEmpty) {
      measurements.removeLast();
    }
  }

  void clear() {
    measurements.clear();
  }

  bool get isEmpty => measurements.isEmpty;
  bool get isNotEmpty => measurements.isNotEmpty;
  int get count => measurements.length;
}
