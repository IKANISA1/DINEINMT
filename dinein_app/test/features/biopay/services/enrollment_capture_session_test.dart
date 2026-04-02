import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:dinein_app/features/biopay/services/enrollment_capture_session.dart';

void main() {
  group('EnrollmentCaptureSession', () {
    test('initializes with correct default values', () {
      final session = EnrollmentCaptureSession();
      expect(session.requiredSamples, 5);
      expect(session.sampleCount, 0);
      expect(session.isComplete, isFalse);
      expect(session.progress, 0.0);
    });

    test('adds valid samples and progresses correctly', () {
      final session = EnrollmentCaptureSession(requiredSamples: 3);

      session.addSample([0.1, 0.2, 0.3], qualityScore: 0.8);
      expect(session.sampleCount, 1);
      expect(session.progress, closeTo(0.333, 0.01));
      expect(session.isComplete, isFalse);

      session.addSample([0.2, 0.3, 0.4], qualityScore: 0.9);
      expect(session.sampleCount, 2);
      expect(session.progress, closeTo(0.666, 0.01));
      expect(session.isComplete, isFalse);

      session.addSample([0.3, 0.4, 0.5], qualityScore: 0.85);
      expect(session.sampleCount, 3);
      expect(session.progress, 1.0);
      expect(session.isComplete, isTrue);
    });

    test('throws ArgumentError on empty embedding', () {
      final session = EnrollmentCaptureSession();
      expect(
        () => session.addSample([], qualityScore: 0.9),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError on mismatched dimensions', () {
      final session = EnrollmentCaptureSession();
      session.addSample([0.1, 0.2], qualityScore: 0.9);
      
      expect(
        () => session.addSample([0.1, 0.2, 0.3], qualityScore: 0.9),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Expected 2-dim embedding'),
        )),
      );
    });

    test('ignores samples added after completion', () {
      final session = EnrollmentCaptureSession(requiredSamples: 2);
      session.addSample([0.1], qualityScore: 0.8);
      session.addSample([0.2], qualityScore: 0.9);
      expect(session.isComplete, isTrue);
      
      session.addSample([0.3], qualityScore: 0.95);
      expect(session.sampleCount, 2); // Still 2
    });

    test('throws StateError when building aggregate before completion', () {
      final session = EnrollmentCaptureSession(requiredSamples: 3);
      session.addSample([0.1], qualityScore: 0.9);
      
      expect(
        () => session.buildAggregate(),
        throwsA(isA<StateError>()),
      );
    });

    test('calculates correct aggregate math (average & L2 normalize)', () {
      final session = EnrollmentCaptureSession(requiredSamples: 2);
      
      // Sample 1: [2.0, 0.0]
      session.addSample([2.0, 0.0], qualityScore: 0.8);
      // Sample 2: [0.0, 2.0]
      session.addSample([0.0, 2.0], qualityScore: 1.0);
      
      // Average vector: [(2+0)/2, (0+2)/2] = [1.0, 1.0]
      // L2 Norm of [1.0, 1.0] = sqrt(1^2 + 1^2) = sqrt(2) ≈ 1.414
      // Normalized: [1.0/sqrt(2), 1.0/sqrt(2)] ≈ [0.707, 0.707]
      // Average Quality: (0.8 + 1.0) / 2 = 0.9
      
      final aggregate = session.buildAggregate();
      
      expect(aggregate.sampleCount, 2);
      expect(aggregate.qualityScore, closeTo(0.9, 0.01));
      
      final expectedComponent = 1.0 / math.sqrt(2);
      expect(aggregate.embedding[0], closeTo(expectedComponent, 0.001));
      expect(aggregate.embedding[1], closeTo(expectedComponent, 0.001));
    });

    test('handles zero magnitude vector gracefully during normalization', () {
      final session = EnrollmentCaptureSession(requiredSamples: 2);
      
      session.addSample([0.0, 0.0], qualityScore: 0.9);
      session.addSample([0.0, 0.0], qualityScore: 0.9);
      
      final aggregate = session.buildAggregate();
      
      // When norm is 0, it should return zeroes.
      expect(aggregate.embedding[0], 0.0);
      expect(aggregate.embedding[1], 0.0);
    });

    test('reset clears internal state perfectly', () {
      final session = EnrollmentCaptureSession(requiredSamples: 2);
      session.addSample([1.0], qualityScore: 0.9);
      
      expect(session.sampleCount, 1);
      
      session.reset();
      
      expect(session.sampleCount, 0);
      expect(session.isComplete, isFalse);
      expect(session.progress, 0.0);
    });
  });
}
