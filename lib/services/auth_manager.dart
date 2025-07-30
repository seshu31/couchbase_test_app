import '../models/user.dart';
import '../repositories/user_repository.dart';
import 'remote_data_service.dart';

class AuthManager {
  AuthManager(this.userRepository, this.remoteDataService);

  final UserRepository userRepository;
  final RemoteDataService remoteDataService;
  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<User?> register(String email, String password) async {
    try {
      // Check if user already exists in remote data
      final existingUser = await remoteDataService.findUserByEmail(email);
      if (existingUser != null) {
        return null; // User already exists
      }
      
      // Create new user and sync to remote
      final user = await remoteDataService.createUser(email, password);
      // Don't set current user after registration - user needs to login separately
      return user;
    } catch (e) {
      throw AuthException('Registration failed: $e');
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      // Check if user exists with provided credentials in remote data
      final user = await remoteDataService.findUserByEmailAndPassword(email, password);
      if (user != null) {
        _currentUser = user;
        return user;
      }
      return null; // User not found or invalid credentials
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