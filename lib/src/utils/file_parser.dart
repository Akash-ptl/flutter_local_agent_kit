import 'dart:convert';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// A utility class to parse various file types into plain text for RAG ingestion.
class FileParser {
  /// Parses the file at [filePath] and returns its text content.
  ///
  /// Supports: .txt, .pdf, .json
  static Future<String> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File does not exist at path: $filePath');
    }

    final extension = filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'txt':
        return _parseText(file);
      case 'pdf':
        return _parsePdf(file);
      case 'json':
        return _parseJson(file);
      default:
        throw UnsupportedError('Unsupported file format: .$extension');
    }
  }

  static Future<String> _parseText(File file) async {
    return file.readAsString();
  }

  static Future<String> _parsePdf(File file) async {
    final List<int> bytes = await file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final String text = extractor.extractText();
    document.dispose();
    return text;
  }

  static Future<String> _parseJson(File file) async {
    final String content = await file.readAsString();
    try {
      final decoded = json.decode(content);
      // If it's a map or list, prettify it for better RAG processing
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (e) {
      // If not valid JSON, just return raw content
      return content;
    }
  }
}
