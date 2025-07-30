import '../models/user.dart';
import '../repositories/user_repository.dart';

class AuthManager {
  AuthManager(this.userRepository);

  final UserRepository userRepository;
  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<User?> register(String email, String password) async {
    try {
      // TODO: Add duplicate check when querying is implemented
      final user = await userRepository.createUser(email, password);
      _currentUser = user;
      return user;
    } catch (e) {
      throw AuthException('Registration failed: $e');
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      // TODO: Implement proper login when querying is implemented
      // For now, create a new user to test functionality
      final user = await userRepository.createUser(email, password);
      _currentUser = user;
      return user;
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  Future<User?> getCurrentUser() async {
    // TODO: Implement persistent session storage
    return _currentUser;
  }

  Future<void> logout() async {
    _currentUser = null;
  }

  bool get isLoggedIn => _currentUser != null;
}

class AuthException implements Exception {
  const AuthException(this.message);
  
  final String message;
  
  @override
  String toString() => 'AuthException: $message';
} 