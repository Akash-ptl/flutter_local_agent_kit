import 'package:flutter_local_agent_kit/src/utils/file_parser.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart';

/// Internal service handling offline document ingestion and semantic search.
class RagService {
  /// The underlying raw RAG engine.
  final MobileRag rag;

  /// Creates a [RagService].
  RagService(this.rag);

  /// Adds a document to the RAG database with optional metadata.
  Future<void> addDocument(String content, {SourceMetadata? metadata}) async {
    // Currently mobile_rag_engine adds text directly, 
    // in future we can attach metadata to the database entry.
    await rag.addDocument(content);
  }

  /// Parses a file and adds its content to the RAG database with metadata.
  Future<void> addFile(String filePath) async {
    final title = filePath.split('/').last;
    final content = await FileParser.parseFile(filePath);
    await addDocument(content, metadata: SourceMetadata(title: title, filePath: filePath));
  }

  /// Retrieves relevant context for a query as structured results.
  Future<List<RetrievalResult>> retrieve(String query,
      {int tokenBudget = 1000}) async {
    final searchResult = await rag.search(
      query,
      tokenBudget: tokenBudget,
    );

    // Map raw context to structured retrieval results
    // Note: mobile_rag_engine 0.1.x returns a consolidated context.
    // We split it back into chunks for citation support if possible, 
    // or return the primary result.
    return [
      RetrievalResult(
        content: searchResult.context.text,
        source: SourceMetadata(title: 'Local Knowledge Base'),
        score: 1.0, // Default score as engine doesn't expose raw scores yet
      )
    ];
  }

  /// Legacy helper for raw text retrieval.
  Future<List<String>> retrieveContext(String query,
      {int tokenBudget = 1000}) async {
    final results = await retrieve(query, tokenBudget: tokenBudget);
    return results.map((r) => r.content).toList();
  }
}
