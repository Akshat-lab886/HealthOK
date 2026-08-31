import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

/// Available AI models for the on-device health coach.
/// Three tiers based on device RAM.
enum ModelTier { micro, lite, standard, advanced }

class AiModel {
  final ModelTier tier;
  final String id;
  final String displayName;
  final String description;
  final String huggingFaceUrl;
  final String fileName;
  final int estimatedSizeMb;
  final int minRamMb;
  final int maxTokens;

  const AiModel({
    required this.tier,
    required this.id,
    required this.displayName,
    required this.description,
    required this.huggingFaceUrl,
    required this.fileName,
    required this.estimatedSizeMb,
    required this.minRamMb,
    this.maxTokens = 512,
  });

  /// Standard tier: Qwen2.5-3B-Instruct Q4_K_M
  /// ~1.9GB download, ~3GB RAM, runs on 6GB+ phones
  /// MMLU 65%, GSM8K 79% — genuinely smart reasoning
  static const standard = AiModel(
    tier: ModelTier.standard,
    id: 'qwen2.5-3b',
    displayName: 'Qwen 2.5 3B (Standard)',
    description:
        'Smart & capable. Great balance of quality and speed.\n'
        '3B params • Q4 quantized • 65% MMLU reasoning score',
    huggingFaceUrl:
        'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
    fileName: 'qwen2.5-3b-instruct-q4_k_m.gguf',
    estimatedSizeMb: 1930,
    minRamMb: 3000,
    maxTokens: 512,
  );

  /// Advanced tier: Phi-3.5-mini-instruct Q4_K_M
  /// ~2.3GB download, ~3.5GB RAM, runs on 8GB+ phones
  /// MMLU 69%, GSM8K 86% — best reasoning in sub-4B class
  static const advanced = AiModel(
    tier: ModelTier.advanced,
    id: 'phi-3.5-mini',
    displayName: 'Phi 3.5 Mini (Advanced)',
    description:
        'Best reasoning ability. Top-tier for health advice.\n'
        '3.8B params • Q4 quantized • 69% MMLU, 86% math score',
    huggingFaceUrl:
        'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
    fileName: 'phi-3.5-mini-instruct-q4_k_m.gguf',
    estimatedSizeMb: 2300,
    minRamMb: 3500,
    maxTokens: 512,
  );

  /// Micro tier: TinyLlama 1.1B Q2_K — smallest possible real GGUF model
  /// ~461MB download, ~600MB RAM with n_ctx=256, attempts to run on 4GB phones
  /// MMLU 25%, GSM8K 3% — very basic but it's a real neural network
  static const micro = AiModel(
    tier: ModelTier.micro,
    id: 'tinyllama-1.1b',
    displayName: 'TinyLlama 1.1B (Micro)',
    description:
        'Tiniest real AI model. May crash on 4GB RAM.\n'
        '1.1B params • Q2 quantized • ~25% MMLU score',
    huggingFaceUrl:
        'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
    fileName: 'tinyllama-1.1b-chat-v1.0.q2_k.gguf',
    estimatedSizeMb: 461,
    minRamMb: 600,
    maxTokens: 256,
  );

  /// Lite tier: Gemma 2 2B IT Q3_K_M (smaller quantization for low-RAM phones)
  /// ~1.46GB download, ~1.8GB RAM, runs on 4GB phones
  /// MMLU 50%, GSM8K 36% — small but capable, fits in limited RAM
  static const lite = AiModel(
    tier: ModelTier.lite,
    id: 'gemma-2-2b',
    displayName: 'Gemma 2 2B (Lite)',
    description:
        'Lightweight & efficient. Best for 4GB RAM phones.\n'
        '2B params • Q3 quantized • 50% MMLU reasoning score',
    huggingFaceUrl:
        'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q3_K_M.gguf',
    fileName: 'gemma-2-2b-it-q3_k_m.gguf',
    estimatedSizeMb: 1460,
    minRamMb: 1800,
    maxTokens: 384,
  );

  static const all = [micro, lite, standard, advanced];

  Future<File> get localFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'models', fileName));
  }

  Future<bool> get isDownloaded async {
    final file = await localFile;
    if (!file.existsSync()) return false;
    // Verify file is at least 95% of expected size (full download).
    // Partial downloads from interrupted network are corrupted.
    final sizeBytes = await file.length();
    final expectedBytes = estimatedSizeMb * 1024 * 1024;
    return sizeBytes >= (expectedBytes * 0.95).toInt();
  }
}

/// Manages model download, deletion, and lifecycle.
class ModelManager extends ChangeNotifier {
  ModelManager() {
    _checkDownloads();
  }

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _downloaded = {};
  String? _activeModelId;

  Map<String, double> get downloadProgress => _downloadProgress;
  Map<String, bool> get downloaded => _downloaded;
  String? get activeModelId => _activeModelId;

  AiModel? get activeModel {
    if (_activeModelId == null) return null;
    return AiModel.all.firstWhere((m) => m.id == _activeModelId);
  }

  Future<void> _checkDownloads() async {
    for (final model in AiModel.all) {
      _downloaded[model.id] = await model.isDownloaded;
    }
    notifyListeners();
  }

  Future<void> downloadModel(AiModel model) async {
    if (_downloaded[model.id] == true) return;

    _downloadProgress[model.id] = 0;
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(p.join(dir.path, 'models'));
      if (!modelsDir.existsSync()) {
        await modelsDir.create(recursive: true);
      }

      // Delete any partial/corrupt file from previous download
      final file = await model.localFile;
      if (file.existsSync()) {
        await file.delete();
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(model.huggingFaceUrl));
      final response = await request.close();

      // Guard against error bodies saved as models (e.g. 15-byte 404 HTML):
      // a real GGUF is hundreds of MB and must come back HTTP 200.
      if (response.statusCode != 200) {
        await response.drain<void>();
        client.close();
        throw Exception(
            'Download failed: HTTP ${response.statusCode} from ${model.huggingFaceUrl}');
      }

      final totalBytes =
          response.contentLength ?? model.estimatedSizeMb * 1024 * 1024;
      int receivedBytes = 0;

      final sink = file.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        _downloadProgress[model.id] = receivedBytes / totalBytes;
        notifyListeners();
      }
      await sink.close();
      client.close();

      // Post-download sanity check: reject tiny/corrupt files
      if (file.lengthSync() < 1024 * 1024) {
        file.deleteSync();
        throw Exception('Downloaded file is too small to be a model — discarded');
      }

      _downloadProgress.remove(model.id);
      _downloaded[model.id] = true;
      notifyListeners();
    } catch (e) {
      _downloadProgress.remove(model.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteModel(AiModel model) async {
    final file = await model.localFile;
    if (file.existsSync()) {
      await file.delete();
    }
    _downloaded[model.id] = false;
    if (_activeModelId == model.id) {
      _activeModelId = null;
    }
    notifyListeners();
  }

  void setActiveModel(String modelId) {
    _activeModelId = modelId;
    notifyListeners();
  }
}
