import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Models
import 'models/user.dart';
import 'models/log_message.dart' as app_models;

// Repositories
import 'repositories/user_repository.dart';
import 'repositories/log_message_repository.dart';

// Services
import 'services/auth_manager.dart';
import 'services/sync_manager.dart';

// Widgets
import 'widgets/login_page.dart';

// Utils
import 'utils/constants.dart';

Future<void> main() async {
  await initApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Couchbase Test App',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
    ),
    home: const AuthWrapper(),
  );
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final user = await authManager.getCurrentUser();
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      // Handle auth state check error
      debugPrint('Auth state check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return LoginPage(onLoginSuccess: (user) {
        setState(() {
          _currentUser = user;
        });
      });
    }
    return LogMessagesPage(currentUser: _currentUser!);
  }
}

class LogMessagesPage extends StatefulWidget {
  const LogMessagesPage({super.key, required this.currentUser});
  final User currentUser;

  @override
  State<LogMessagesPage> createState() => _LogMessagesPageState();
}

class _LogMessagesPageState extends State<LogMessagesPage> {
  List<app_models.AppLogMessage> _logMessages = [];
  StreamSubscription? _logMessagesSub;
  StreamSubscription? _syncStatusSub;
  String _syncStatus = 'Disconnected';
  bool _showAllMessages = false;
  final Map<String, String> _userEmailCache = {};

  @override
  void initState() {
    super.initState();
    _setupLogMessagesStream();
    _setupSyncStatusListener();
    _startSync();
  }

  void _setupLogMessagesStream() {
    _logMessagesSub?.cancel();
    _logMessagesSub = (_showAllMessages 
        ? logMessageRepository.allLogMessagesStream()
        : logMessageRepository.userLogMessagesStream(widget.currentUser.id)
    ).listen(
      (logMessages) => setState(() => _logMessages = logMessages),
      onError: (error) => debugPrint('Log messages stream error: $error'),
    );
  }

  void _setupSyncStatusListener() {
    _syncStatusSub = syncManager.statusStream?.listen(
      (status) => setState(() => _syncStatus = _getSyncStatusText(status)),
      onError: (error) => debugPrint('Sync status stream error: $error'),
    );
  }

  void _startSync() {
    try {
      syncManager.startSync();
    } catch (e) {
      debugPrint('Failed to start sync: $e');
    }
  }

  String? _getUserEmail(app_models.AppLogMessage logMessage) {
    if (logMessage is app_models.CblLogMessage && logMessage.userId != null) {
      final userId = logMessage.userId!;
      if (_userEmailCache.containsKey(userId)) {
        return _userEmailCache[userId];
      }
      // Try to get from current user first
      if (userId == widget.currentUser.id) {
        _userEmailCache[userId] = widget.currentUser.email;
        return widget.currentUser.email;
      }
      // Query the user repository for the email
      userRepository.findUserById(userId).then((user) {
        if (user != null && mounted) {
          setState(() {
            _userEmailCache[userId] = user.email;
          });
        }
      });
      // Return placeholder until we get the real email
      return 'user_${userId.substring(0, 8)}';
    }
    return null;
  }

  String _getSyncStatusText(ReplicatorStatus status) {
    switch (status.activity) {
      case ReplicatorActivityLevel.stopped:
        return 'Stopped';
      case ReplicatorActivityLevel.offline:
        return 'Offline';
      case ReplicatorActivityLevel.connecting:
        return 'Connecting...';
      case ReplicatorActivityLevel.idle:
        return 'Connected (Idle)';
      case ReplicatorActivityLevel.busy:
        return 'Syncing...';
    }
  }

  Future<void> _handleLogout() async {
    try {
      await authManager.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }

  void _toggleMessageView() {
    setState(() {
      _showAllMessages = !_showAllMessages;
      _setupLogMessagesStream();
    });
  }

  @override
  void dispose() {
    _logMessagesSub?.cancel();
    _syncStatusSub?.cancel();
    syncManager.stopSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Log Messages'),
      actions: [
        _buildSyncStatusIndicator(),
        _buildViewToggleButton(),
        _buildLogoutMenu(),
      ],
    ),
    body: SafeArea(
      child: Column(children: [
        Expanded(child: _buildMessagesList()),
        const Divider(height: 0),
        _buildMessageForm(),
      ]),
    ),
  );

  Widget _buildSyncStatusIndicator() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          _syncStatus,
          style: TextStyle(
            color: _syncStatus.contains('Connected') || _syncStatus.contains('Syncing')
                ? Colors.green
                : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton() {
    return IconButton(
      icon: Icon(_showAllMessages ? Icons.person : Icons.people),
      onPressed: _toggleMessageView,
      tooltip: _showAllMessages ? 'Show my messages' : 'Show all messages',
    );
  }

  Widget _buildLogoutMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'logout') {
          _handleLogout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout),
              const SizedBox(width: 8),
              Text('Logout (${widget.currentUser.email})'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      reverse: true,
      itemCount: _logMessages.length,
      itemBuilder: (context, index) {
        final logMessage = _logMessages[_logMessages.length - 1 - index];
        return LogMessageTile(
          logMessage: logMessage,
          showUser: _showAllMessages,
          userEmail: _showAllMessages ? _getUserEmail(logMessage) : null,
        );
      },
    );
  }

  Widget _buildMessageForm() {
    return LogMessageForm(
      onSubmit: (message) => logMessageRepository.createLogMessage(
        message,
        userId: widget.currentUser.id,
      ),
    );
  }
}

class LogMessageTile extends StatelessWidget {
  const LogMessageTile({
    super.key, 
    required this.logMessage,
    this.showUser = false,
    this.userEmail,
  });

  final app_models.AppLogMessage logMessage;
  final bool showUser;
  final String? userEmail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppConstants.spacing),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              DateFormat.yMd().add_jm().format(logMessage.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (showUser && userEmail != null) ...[
              const SizedBox(width: AppConstants.spacing),
              _buildUserLabel(context),
            ],
          ],
        ),
        const SizedBox(height: AppConstants.spacing / 4),
        Text(logMessage.message)
      ],
    ),
  );

  Widget _buildUserLabel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        userEmail!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class LogMessageForm extends StatefulWidget {
  const LogMessageForm({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<LogMessageForm> createState() => _LogMessageFormState();
}

class _LogMessageFormState extends State<LogMessageForm> {
  late final TextEditingController _messageController;
  late final FocusNode _messageFocusNode;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messageFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    widget.onSubmit(message);
    _messageController.clear();
    _messageFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppConstants.spacing),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration.collapsed(hintText: 'Message'),
            autofocus: true,
            focusNode: _messageFocusNode,
            controller: _messageController,
            minLines: 1,
            maxLines: 10,
            style: Theme.of(context).textTheme.bodyMedium,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        const SizedBox(width: AppConstants.spacing / 2),
        TextButton(
          onPressed: _onSubmit,
          child: const Text('Write to log'),
        )
      ],
    ),
  );
}

// Global instances
late Database database;
late Collection logMessages;
late Collection users;
late LogMessageRepository logMessageRepository;
late UserRepository userRepository;
late AuthManager authManager;
late SyncManager syncManager;

/// Initializes global app state.
Future<void> initApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TracingDelegate.install(DevToolsTracing());
  await CouchbaseLiteFlutter.init();

  await _initializeDatabase();
  await _createIndexes();
  await _initializeRepositories();
  await _initializeServices();
}

Future<void> _initializeDatabase() async {
  database = await Database.openAsync(AppConstants.databaseName);
  logMessages = await database.createCollection(AppConstants.logMessagesCollection);
  users = await database.createCollection(AppConstants.usersCollection);
}

Future<void> _createIndexes() async {
  // Create indexes for logMessages
  await logMessages.createIndex(
    AppConstants.logMessagesIndex,
    ValueIndex([
      ValueIndexItem.property('type'),
      ValueIndexItem.property('createdAt'),
    ]),
  );

  // Create indexes for users
  await users.createIndex(
    AppConstants.usersIndex,
    ValueIndex([
      ValueIndexItem.property('type'),
      ValueIndexItem.property('email'),
    ]),
  );
}

Future<void> _initializeRepositories() async {
  logMessageRepository = LogMessageRepository(database, logMessages);
  userRepository = UserRepository(database, users);
}

Future<void> _initializeServices() async {
  authManager = AuthManager(userRepository);
  syncManager = SyncManager();
  await syncManager.initialize(database, [logMessages, users]);
}