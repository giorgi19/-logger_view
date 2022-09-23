import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

const double G = 9.81;

class ShakeDetector {
  ShakeDetector({
    required this.onPhoneShake,
    this.shakeThresholdGravity = 1.25,
    this.minTimeBetweenShakes = 150,
    this.shakeCountResetTime = 1500,
    this.minShakeCount = 3,
  });

  final VoidCallback onPhoneShake;
  final double shakeThresholdGravity;
  final int minTimeBetweenShakes;
  final int shakeCountResetTime;
  final int minShakeCount;

  int _shakeCount = 0;
  int _lastShakeTimestamp = DateTime.now().millisecondsSinceEpoch;

  StreamSubscription<AccelerometerEvent>? _eventsSubscription;

  /// Starts listening to accelerometer events
  void startListening() {
    _eventsSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      final double gX = event.x / G;
      final double gY = event.y / G;
      final double gZ = event.z / G;

      // gForce will be close to 1 when there is no movement.
      final double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);
      if (gForce > shakeThresholdGravity) {
        final int now = DateTime.now().millisecondsSinceEpoch;
        // ignore shake events too close to each other
        if (_lastShakeTimestamp + minTimeBetweenShakes > now) {
          return;
        }

        // reset the shake count after 1.5 seconds of no shakes
        if (_lastShakeTimestamp + shakeCountResetTime < now) {
          _shakeCount = 0;
        }

        _lastShakeTimestamp = now;
        if (++_shakeCount >= minShakeCount) {
          _shakeCount = 0;
          onPhoneShake();
        }
      }
    });
  }

  /// Stops listening to accelerometer events
  void stopListening() => _eventsSubscription?.cancel();
}
