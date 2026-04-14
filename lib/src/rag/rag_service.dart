import 'package:mobile_rag_engine/mobile_rag_engine.dart';

/// Internal service handling offline document ingestion and semantic search.
class RagService {
  /// The underlying raw RAG engine.
  final MobileRag rag;

  /// Creates a [RagService].
  RagService(this.rag);

  /// Adds a document to the RAG database.
  Future<void> addDocument(String content) async {
    await rag.addDocument(content);
  }

  /// Retrieves relevant context for a query.
  Future<List<String>> retrieveContext(String query, {int tokenBudget = 1000}) async {
    final searchResult = await rag.search(
      query,
      tokenBudget: tokenBudget,
    );
    
    return [searchResult.context.text];
  }
}
