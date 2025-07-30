import 'package:cbl/cbl.dart';
import '../models/user.dart';

class UserRepository {
  const UserRepository(this.database, this.collection);

  final Database database;
  final Collection collection;

  Future<User> createUser(String email, String password) async {
    try {
      final doc = MutableDocument({
        'type': 'user',
        'email': email,
        'password': password, // In production, this should be hashed
        'createdAt': DateTime.now(),
      });
      await collection.saveDocument(doc);
      return User.fromDict(doc);
    } catch (e) {
      throw UserRepositoryException('Failed to create user: $e');
    }
  }

  Future<User?> findUserByEmail(String email) async {
    try {
      // TODO: Implement proper querying when ResultSet API is fixed
      return null;
    } catch (e) {
      throw UserRepositoryException('Failed to find user by email: $e');
    }
  }

  Future<User?> findUserByEmailAndPassword(String email, String password) async {
    try {
      // TODO: Implement proper querying when ResultSet API is fixed
      return null;
    } catch (e) {
      throw UserRepositoryException('Failed to find user by credentials: $e');
    }
  }

  Future<User?> findUserById(String userId) async {
    try {
      final doc = await collection.document(userId);
      if (doc != null) {
        return User.fromDict(doc);
      }
      return null;
    } catch (e) {
      throw UserRepositoryException('Failed to find user by ID: $e');
    }
  }

  Stream<List<User>> allUsersStream() {
    try {
      final query = const QueryBuilder()
          .select(
        SelectResult.expression(Meta.id),
        SelectResult.property('email'),
        SelectResult.property('createdAt'),
      )
          .from(DataSource.collection(collection))
          .where(
        Expression.property('type').equalTo(Expression.value('user')),
      )
          .orderBy(Ordering.property('createdAt'));

      return query.changes().asyncMap(
            (change) => change.results.asStream().map(User.fromDict).toList(),
      );
    } catch (e) {
      throw UserRepositoryException('Failed to get users stream: $e');
    }
  }
}

class UserRepositoryException implements Exception {
  const UserRepositoryException(this.message);
  
  final String message;
  
  @override
  String toString() => 'UserRepositoryException: $message';
} 