import 'dart:async';
import 'package:cbl/cbl.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';
import '../services/sync_manager.dart';

class RemoteDataService {
  RemoteDataService(this.userRepository, this.syncManager);

  final UserRepository userRepository;
  final SyncManager syncManager;
  Timer? _syncTimer;

  /// Ensures data is synced with Capella before performing operations
  Future<void> ensureSync() async {
    try {
      // Start sync if not already running
      if (!syncManager.isInitialized) {
        throw Exception('Sync manager not initialized');
      }
      
      syncManager.startSync();
      
      // Wait for initial sync to complete with shorter timeout
      await _waitForSync();
    } catch (e) {
      // If sync fails, we'll still try to work with local data
      debugPrint('Sync failed, continuing with local data: $e');
      // Don't throw error, just continue with local data
    }
  }

  /// Waits for sync to complete or timeout
  Future<void> _waitForSync() async {
    final completer = Completer<void>();
    Timer? timeoutTimer;
    StreamSubscription? statusSubscription;

    try {
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.completeError('Sync timeout');
        }
      });

      statusSubscription = syncManager.statusStream?.listen((status) {
        if (status.activity == ReplicatorActivityLevel.idle || 
            status.activity == ReplicatorActivityLevel.busy) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });

      await completer.future;
    } finally {
      timeoutTimer?.cancel();
      statusSubscription?.cancel();
    }
  }

  /// Find user by email from remote data
  Future<User?> findUserByEmail(String email) async {
    try {
      await ensureSync();
      return await userRepository.findUserByEmail(email);
    } catch (e) {
      // Fallback to local data if sync fails
      debugPrint('Remote sync failed, trying local data: $e');
      try {
        return await userRepository.findUserByEmail(email);
      } catch (localError) {
        throw RemoteDataException('Failed to find user by email: $localError');
      }
    }
  }

  /// Find user by email and password from remote data
  Future<User?> findUserByEmailAndPassword(String email, String password) async {
    try {
      await ensureSync();
      return await userRepository.findUserByEmailAndPassword(email, password);
    } catch (e) {
      // Fallback to local data if sync fails
      debugPrint('Remote sync failed, trying local data: $e');
      try {
        return await userRepository.findUserByEmailAndPassword(email, password);
      } catch (localError) {
        throw RemoteDataException('Failed to find user by credentials: $localError');
      }
    }
  }

  /// Create user and ensure it syncs to remote
  Future<User> createUser(String email, String password) async {
    try {
      await ensureSync();
      final user = await userRepository.createUser(email, password);
      
      // Wait for the new user to sync to remote
      await _waitForSync();
      
      return user;
    } catch (e) {
      throw RemoteDataException('Failed to create user: $e');
    }
  }

  /// Get all users from remote data
  Stream<List<User>> getAllUsers() {
    try {
      ensureSync();
      return userRepository.allUsersStream();
    } catch (e) {
      throw RemoteDataException('Failed to get all users: $e');
    }
  }

  /// Check if we have any local users (for debugging)
  Future<List<User>> getLocalUsers() async {
    try {
      final results = await userRepository.allUsersStream().first;
      return results;
    } catch (e) {
      debugPrint('Failed to get local users: $e');
      return [];
    }
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}

class RemoteDataException implements Exception {
  const RemoteDataException(this.message);
  
  final String message;
  
  @override
  String toString() => 'RemoteDataException: $message';
} 