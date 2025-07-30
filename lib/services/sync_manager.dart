import 'dart:async';
import 'package:cbl/cbl.dart';

class SyncManager {
  Replicator? _replicator;
  StreamController<ReplicatorStatus>? _statusController;

  Stream<ReplicatorStatus>? get statusStream => _statusController?.stream;

  Future<void> initialize(Database database, List<Collection> collections) async {
    try {
      _statusController = StreamController<ReplicatorStatus>.broadcast();

      const syncUrl = 'wss://mdzlz4prx2ertg.apps.cloud.couchbase.com:4984/test_endpoint';
      final target = UrlEndpoint(Uri.parse(syncUrl));

      final config = ReplicatorConfiguration(target: target)
        ..replicatorType = ReplicatorType.pushAndPull
        ..continuous = true
        ..authenticator = BasicAuthenticator(
          username: 'test',
          password: 'Test@123',
        );
      
      // Add all collections to sync
      for (final collection in collections) {
        config.addCollection(collection);
      }

      _replicator = await Replicator.create(config);

      // Listen to status changes
      _replicator!.changes().listen((change) {
        _statusController?.add(change.status);
      });
    } catch (e) {
      throw SyncException('Failed to initialize sync: $e');
    }
  }

  void startSync() {
    try {
      _replicator?.start();
    } catch (e) {
      throw SyncException('Failed to start sync: $e');
    }
  }

  void stopSync() {
    try {
      _replicator?.stop();
    } catch (e) {
      throw SyncException('Failed to stop sync: $e');
    }
  }

  void dispose() {
    try {
      _replicator?.stop();
      _statusController?.close();
    } catch (e) {
      // Ignore errors during disposal
    }
  }

  bool get isInitialized => _replicator != null;
}

class SyncException implements Exception {
  const SyncException(this.message);
  
  final String message;
  
  @override
  String toString() => 'SyncException: $message';
} 