# Couchbase Test App

A Flutter application demonstrating **Couchbase Lite** integration with **real-time synchronization** and **user authentication**.

## Features

### 🔐 Authentication System

- **User Registration**: Create new accounts with email and password
- **User Login**: Secure authentication with email/password
- **Session Management**: Automatic login state persistence
- **User-specific Data**: Each user sees their own log messages

### 📝 Log Message Management

- **Create Messages**: Users can write and submit log messages
- **Real-time Updates**: Messages appear instantly across devices
- **User Association**: Messages are linked to specific users
- **Admin View**: Toggle between personal and all users' messages

### 🔄 Bidirectional Sync

- **Offline-First**: Works without internet connection
- **Real-time Sync**: Automatic synchronization with Couchbase Cloud
- **Multi-Collection Sync**: Syncs both users and log messages collections
- **Status Monitoring**: Visual sync status indicator

## Technical Architecture

### Database Collections

- **`users`**: Stores user accounts with email and password
- **`logMessages`**: Stores log messages with user associations

### Key Components

- **`AuthManager`**: Handles user authentication and session management
- **`UserRepository`**: Manages user data operations
- **`LogMessageRepository`**: Manages log message operations
- **`SyncManager`**: Handles bidirectional sync with Couchbase Cloud

### Sync Configuration

- **Endpoint**: `wss://mdzlz4prx2ertg.apps.cloud.couchbase.com:4984/test_endpoint`
- **Authentication**: Basic auth with test credentials
- **Collections**: Both `users` and `logMessages` collections are synced

## Getting Started

1. **Prerequisites**: Ensure you have Flutter installed
2. **Dependencies**: Run `flutter pub get`
3. **Configuration**: Update sync endpoint in `SyncManager` if needed
4. **Run**: Execute `flutter run`

## Usage

1. **Register/Login**: Create an account or login with existing credentials
2. **Write Messages**: Use the text field to create log messages
3. **View Messages**: See your messages in real-time
4. **Toggle Views**: Use the people icon to switch between personal and all messages
5. **Sync Status**: Monitor connection status in the app bar
6. **Logout**: Use the menu to logout

## Security Notes

- Passwords are stored in plain text (for demo purposes)
- In production, implement proper password hashing
- Consider implementing JWT tokens for authentication
- Add input validation and sanitization

## Dependencies

- `cbl_flutter`: Couchbase Lite for Flutter
- `cbl_flutter_ce`: Community Edition
- `intl`: Internationalization and date formatting
- `flutter`: Flutter framework
