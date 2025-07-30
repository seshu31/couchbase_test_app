import 'package:cbl/cbl.dart';
import '../models/log_message.dart' as app_models;

class LogMessageRepository {
  const LogMessageRepository(this.database, this.collection);

  final Database database;
  final Collection collection;

  Future<app_models.AppLogMessage> createLogMessage(String message, {String? userId}) async {
    try {
      final doc = MutableDocument({
        'type': 'logMessage',
        'createdAt': DateTime.now(),
        'message': message,
        if (userId != null) 'userId': userId,
      });
      await collection.saveDocument(doc);
      return app_models.CblLogMessage(doc);
    } catch (e) {
      throw LogMessageRepositoryException('Failed to create log message: $e');
    }
  }

  Stream<List<app_models.AppLogMessage>> allLogMessagesStream() {
    try {
      final query = const QueryBuilder()
          .select(
        SelectResult.expression(Meta.id),
        SelectResult.property('createdAt'),
        SelectResult.property('message'),
        SelectResult.property('userId'),
      )
          .from(DataSource.collection(collection))
          .where(
        Expression.property('type').equalTo(Expression.value('logMessage')),
      )
          .orderBy(Ordering.property('createdAt'));

      return query.changes().asyncMap(
            (change) => change.results.asStream().map(app_models.CblLogMessage.new).toList(),
      );
    } catch (e) {
      throw LogMessageRepositoryException('Failed to get all log messages stream: $e');
    }
  }

  Stream<List<app_models.AppLogMessage>> userLogMessagesStream(String userId) {
    try {
      final query = const QueryBuilder()
          .select(
        SelectResult.expression(Meta.id),
        SelectResult.property('createdAt'),
        SelectResult.property('message'),
        SelectResult.property('userId'),
      )
          .from(DataSource.collection(collection))
          .where(
        Expression.property('type').equalTo(Expression.value('logMessage')).and(
          Expression.property('userId').equalTo(Expression.value(userId)),
        ),
      )
          .orderBy(Ordering.property('createdAt'));

      return query.changes().asyncMap(
            (change) => change.results.asStream().map(app_models.CblLogMessage.new).toList(),
      );
    } catch (e) {
      throw LogMessageRepositoryException('Failed to get user log messages stream: $e');
    }
  }
}

class LogMessageRepositoryException implements Exception {
  const LogMessageRepositoryException(this.message);
  
  final String message;
  
  @override
  String toString() => 'LogMessageRepositoryException: $message';
} 