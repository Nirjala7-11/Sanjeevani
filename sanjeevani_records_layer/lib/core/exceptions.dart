/// Typed exception hierarchy for the records layer.
///
/// Every exception this package surfaces inherits from [RecordsException].
/// Callers catch one base type; subtypes give fine-grained handling.
library;

/// Base class for all records-layer exceptions.
class RecordsException implements Exception {
  const RecordsException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      cause != null ? '$message (caused by: $cause)' : message;
}

/// Raised when the SQLite database cannot be opened or migrated.
class DatabaseException extends RecordsException {
  const DatabaseException(super.message, {super.cause});
}

/// Raised when a required record is not found.
class RecordNotFoundException extends RecordsException {
  const RecordNotFoundException(String entity, dynamic id)
      : super('$entity with id=$id was not found.');
}

/// Raised when data violates an integrity constraint before being written.
class ValidationException extends RecordsException {
  const ValidationException(super.message);
}

/// Raised when a sync operation fails.
class SyncException extends RecordsException {
  const SyncException(super.message, {super.cause});
}

/// Raised when the knowledge base file is missing, empty, or malformed.
class KnowledgeBaseException extends RecordsException {
  const KnowledgeBaseException(super.message, {super.cause});
}
