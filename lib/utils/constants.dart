class AppConstants {
  static const double spacing = 16.0;
  static const String databaseName = 'test_bucket';
  static const String logMessagesCollection = 'logMessages';
  static const String usersCollection = 'users';
  static const String syncUrl = 'wss://mdzlz4prx2ertg.apps.cloud.couchbase.com:4984/test_endpoint';
  static const String syncUsername = 'test';
  static const String syncPassword = 'Test@123';
  
  // Index names
  static const String logMessagesIndex = 'type+createdAt';
  static const String usersIndex = 'type+email';
  
  // Document types
  static const String logMessageType = 'logMessage';
  static const String userType = 'user';
  
  // Validation
  static const int minPasswordLength = 6;
} 