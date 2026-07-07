/// Knowledge base loader and validator for the Dart side.
///
/// The medical protocol content lives in data/knowledge_base.json.
/// This class loads, validates, and exposes it as typed objects.
///
/// The actual semantic retrieval (FAISS nearest-neighbour search) happens
/// in the Python intelligence layer — this class provides:
///   (a) Schema validation at app startup so corrupted content surfaces early.
///   (b) A typed [KnowledgeEntry] model for any UI display of sources.
///   (c) A simple keyword filter for the patient records UI to show
///       relevant protocol hints without calling the intelligence layer.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:sanjeevani_records/core/exceptions.dart';

/// One entry in the knowledge base.
class KnowledgeEntry {
  const KnowledgeEntry({
    required this.id,
    required this.text,
    required this.sourceRef,
    required this.tags,
  });

  final String id;
  final String text;
  final String sourceRef;
  final List<String> tags;

  factory KnowledgeEntry.fromJson(Map<String, dynamic> j) {
    final missing = <String>[];
    for (final k in ['id', 'text', 'source_ref']) {
      if (!j.containsKey(k)) missing.add(k);
    }
    if (missing.isNotEmpty) {
      throw KnowledgeBaseException(
        'Knowledge base entry is missing required fields: $missing',
      );
    }
    return KnowledgeEntry(
      id: j['id'] as String,
      text: j['text'] as String,
      sourceRef: j['source_ref'] as String,
      tags: List<String>.from(j['tags'] as List? ?? []),
    );
  }
}

class KnowledgeStore {
  KnowledgeStore._();

  static final KnowledgeStore instance = KnowledgeStore._();
  static final _log = Logger('sanjeevani.records.knowledge');

  List<KnowledgeEntry>? _entries;

  /// Load and validate the knowledge base from assets.
  /// Safe to call multiple times — loads only once.
  Future<void> load({String assetPath = 'data/knowledge_base.json'}) async {
    if (_entries != null) return;

    _log.info('Loading knowledge base from $assetPath');
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (e) {
      throw KnowledgeBaseException(
        'Knowledge base asset not found at $assetPath. '
        'Ensure it is listed in pubspec.yaml assets.',
        cause: e,
      );
    }

    List<dynamic> parsed;
    try {
      parsed = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      throw KnowledgeBaseException(
        'knowledge_base.json contains invalid JSON.',
        cause: e,
      );
    }

    if (parsed.isEmpty) {
      throw const KnowledgeBaseException(
        'knowledge_base.json is empty. '
        'At least one protocol entry is required.',
      );
    }

    final entries = <KnowledgeEntry>[];
    for (int i = 0; i < parsed.length; i++) {
      try {
        entries.add(KnowledgeEntry.fromJson(parsed[i] as Map<String, dynamic>));
      } catch (e) {
        throw KnowledgeBaseException(
          'Error parsing knowledge base entry #$i: $e',
        );
      }
    }

    _entries = entries;
    _log.info('Knowledge base loaded: ${_entries!.length} entries');
  }

  /// All entries (throws if load() has not been called).
  List<KnowledgeEntry> get all {
    if (_entries == null) {
      throw const KnowledgeBaseException(
        'KnowledgeStore.load() must be called before accessing entries.',
      );
    }
    return List.unmodifiable(_entries!);
  }

  /// Simple keyword filter — for UI source display only.
  /// The real semantic search happens in the Python intelligence layer.
  List<KnowledgeEntry> filterByTag(String tag) =>
      all.where((e) => e.tags.contains(tag)).toList();

  /// Find an entry by its id (for displaying protocol source citations).
  KnowledgeEntry? findById(String id) {
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  int get count => _entries?.length ?? 0;
}
