import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

/// Configuration for a downloadable LLM model.
class ModelDefinition {
  /// Unique identifier for the model (e.g. 'llama-3-8b').
  final String id;

  /// The direct URL to download the .gguf file.
  final String url;

  /// Human-readable name for the model.
  final String name;

  /// Estimated size in bytes for progress calculations.
  final int estimatedSizeInBytes;

  /// Expected SHA-256 checksum to verify file integrity.
  final String? sha256;

  /// Creates a [ModelDefinition].
  ModelDefinition({
    required this.id,
    required this.url,
    required this.name,
    this.estimatedSizeInBytes = 0,
    this.sha256,
  });
}

/// A robust utility for managing local GGUF model files.
class ModelManager {
  /// Internal constructor for [ModelManager].
  ModelManager();

  final Dio _dio = Dio();

  /// Returns the local directory where models are persisted.
  Future<Directory> get modelDir async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDocDir.path, 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns true if the model with the given [modelId] exists locally.
  Future<bool> isModelDownloaded(String modelId) async {
    final path = await getLocalPath(modelId);
    return File(path).existsSync();
  }

  /// Constructs the absolute local filesystem path for a [modelId].
  Future<String> getLocalPath(String modelId) async {
    final dir = await modelDir;
    return p.join(dir.path, '$modelId.gguf');
  }

  /// Downloads a model from a remote URL to local storage.
  ///
  /// Provides an optional [onProgress] callback returning 0.0 to 1.0.
  Future<File> downloadModel(
    ModelDefinition model, {
    void Function(double)? onProgress,
  }) async {
    final savePath = await getLocalPath(model.id);

    try {
      await _dio.download(
        model.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      final file = File(savePath);

      if (model.sha256 != null) {
        final isValid = await verifyIntegrity(model.id, model.sha256!);
        if (!isValid) {
          await file.delete();
          throw Exception('Integrity check failed: SHA-256 mismatch.');
        }
      }

      return file;
    } catch (e) {
      final partialFile = File(savePath);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      rethrow;
    }
  }

  /// Verifies the SHA-256 checksum of a local model.
  Future<bool> verifyIntegrity(String modelId, String expectedSha256) async {
    final path = await getLocalPath(modelId);
    final file = File(path);
    if (!await file.exists()) return false;

    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString().toLowerCase() == expectedSha256.toLowerCase();
  }

  /// Lists all models currently stored in the local models directory.
  Future<List<String>> listLocalModels() async {
    final dir = await modelDir;
    final List<FileSystemEntity> entities = await dir.list().toList();
    return entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.gguf'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }

  /// Permanently removes a model from the local device.
  Future<void> deleteModel(String modelId) async {
    final path = await getLocalPath(modelId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// A pre-curated list of high-performance models for 2026 hardware.
  static List<ModelDefinition> get recommendedModels => [
        ModelDefinition(
          id: 'llama-3.2-1b-instruct',
          name: 'Llama 3.2 (1B) - Best for Mobile',
          url:
              'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
          estimatedSizeInBytes: 742000000,
        ),
        ModelDefinition(
          id: 'phi-3-mini-4k',
          name: 'Phi-3 Mini (3.8B) - Fast',
          url:
              'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
          estimatedSizeInBytes: 2300000000,
        ),
      ];
}
