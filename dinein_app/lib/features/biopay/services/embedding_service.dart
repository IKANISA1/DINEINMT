import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device face embedding using MobileFaceNet TFLite.
///
/// Loads the bundled MobileFaceNet model, runs inference on
/// aligned 112×112 face crops, and returns L2-normalized
/// embedding vectors whose length is detected from the model.
///
/// No face images are stored — frames are processed in memory only.
class EmbeddingService {
  Interpreter? _interpreter;
  Future<void>? _initializing;

  static const String _modelAsset = 'assets/ml/mobilefacenet.tflite';
  static const int _inputSize = 112;
  int _embeddingDim = 0;

  /// Load the MobileFaceNet TFLite model.
  Future<void> initialize() async {
    if (_interpreter != null) return;
    if (_initializing != null) {
      await _initializing;
      return;
    }

    _initializing = () async {
      _interpreter = await Interpreter.fromAsset(
        _modelAsset,
        options: InterpreterOptions()..threads = 2,
      );
      // Detect output embedding dimension from the model's output tensor
      _embeddingDim = _interpreter!.getOutputTensor(0).shape.last;
    }();

    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  /// Run inference on a pre-aligned face crop.
  ///
  /// [alignedFace] must be a 112×112×3 Float32 array (RGB, [-1, 1] normalized).
  /// Returns L2-normalized embedding vector (dimension detected from model).
  List<double> getEmbedding(Float32List alignedFace) {
    if (_interpreter == null) {
      throw StateError('EmbeddingService not initialized');
    }

    if (alignedFace.length != _inputSize * _inputSize * 3) {
      throw ArgumentError(
        'Expected ${_inputSize * _inputSize * 3} floats, got ${alignedFace.length}',
      );
    }

    // Reshape to [1, 112, 112, 3]
    final input = alignedFace.reshape([1, _inputSize, _inputSize, 3]);

    // Output: [1, _embeddingDim] (detected from model)
    // NOTE: tflite_flutter's Tensor._duplicateList creates List<double>
    // internally, which cannot be stored in a Float32List. Using
    // List<List<double>> as the output buffer avoids the type mismatch.
    final output = List.generate(
      1,
      (_) => List<double>.filled(_embeddingDim, 0),
    );

    _interpreter!.run(input, output);

    // L2-normalize
    return _l2Normalize(output[0]);
  }

  /// L2-normalize a vector to unit length.
  List<double> _l2Normalize(List<double> raw) {
    double sumSquares = 0;
    for (final v in raw) {
      sumSquares += v * v;
    }

    final norm = math.sqrt(sumSquares);
    if (norm < 1e-10) {
      return List.filled(_embeddingDim, 0);
    }

    return List.generate(_embeddingDim, (i) => raw[i] / norm);
  }

  /// The embedding vector length produced by this model.
  int get embeddingDim => _embeddingDim;

  /// Release interpreter resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initializing = null;
  }
}
