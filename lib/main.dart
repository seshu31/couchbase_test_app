import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> main() async {
  await initApp();
  runApp(const MyApp());
}

const spacing = 16.0;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
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
    final user = await authManager.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoginSuccess});

  final ValueChanged<User> onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? user;
      if (_isRegistering) {
        user = await authManager.register(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        user = await authManager.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      if (user != null) {
        widget.onLoginSuccess(user);
      } else {
        setState(() {
          _errorMessage = _isRegistering 
              ? 'Registration failed. User might already exist.'
              : 'Invalid email or password.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isRegistering ? 'Register' : 'Login'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(spacing),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: spacing),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: spacing),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: spacing),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(_isRegistering ? 'Register' : 'Login'),
              ),
            ),
            const SizedBox(height: spacing / 2),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _isRegistering = !_isRegistering),
              child: Text(_isRegistering
                  ? 'Already have an account? Login'
                  : 'Don\'t have an account? Register'),
            ),
          ],
        ),
      ),
    ),
  );
}

class LogMessagesPage extends StatefulWidget {
  const LogMessagesPage({super.key, required this.currentUser});
  final User currentUser;

  @override
  State<LogMessagesPage> createState() => _LogMessagesPageState();
}

class _LogMessagesPageState extends State<LogMessagesPage> {
  List<LogMessage> _logMessages = [];
  StreamSubscription? _logMessagesSub;
  StreamSubscription? _syncStatusSub;
  String _syncStatus = 'Disconnected';
  bool _showAllMessages = false;
  Map<String, String> _userEmailCache = {};

  @override
  void initState() {
    super.initState();
    _setupLogMessagesStream();

    // Listen to sync status
    _syncStatusSub = syncManager.statusStream.listen((status) {
      setState(() {
        _syncStatus = _getSyncStatusText(status);
      });
    });

    // Start sync
    syncManager.startSync();
  }

  void _setupLogMessagesStream() {
    _logMessagesSub?.cancel();
    _logMessagesSub = (_showAllMessages 
        ? logMessageRepository.allLogMessagesStream()
        : logMessageRepository.userLogMessagesStream(widget.currentUser.id)
    ).listen((logMessages) {
      setState(() => _logMessages = logMessages);
    });
  }

  String? _getUserEmail(LogMessage logMessage) {
    if (logMessage is CblLogMessage && logMessage.userId != null) {
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
        if (user != null) {
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
        Padding(
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
        ),
        IconButton(
          icon: Icon(_showAllMessages ? Icons.person : Icons.people),
          onPressed: () {
            setState(() {
              _showAllMessages = !_showAllMessages;
              _setupLogMessagesStream();
            });
          },
          tooltip: _showAllMessages ? 'Show my messages' : 'Show all messages',
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'logout') {
              await authManager.logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                );
              }
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
        ),
      ],
    ),
    body: SafeArea(
      child: Column(children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: _logMessages.length,
            itemBuilder: (context, index) {
              final logMessage =
              _logMessages[_logMessages.length - 1 - index];

              return LogMessageTile(
                logMessage: logMessage,
                showUser: _showAllMessages,
                userEmail: _showAllMessages ? _getUserEmail(logMessage) : null,
              );
            },
          ),
        ),
        const Divider(height: 0),
        _LogMessageForm(
          onSubmit: (message) => logMessageRepository.createLogMessage(
            message,
            userId: widget.currentUser.id,
          ),
        )
      ]),
    ),
  );
}

class LogMessageTile extends StatelessWidget {
  const LogMessageTile({
    super.key, 
    required this.logMessage,
    this.showUser = false,
    this.userEmail,
  });

  final LogMessage logMessage;
  final bool showUser;
  final String? userEmail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(spacing),
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
              const SizedBox(width: spacing),
              Container(
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
              ),
            ],
          ],
        ),
        const SizedBox(height: spacing / 4),
        Text(logMessage.message)
      ],
    ),
  );
}

class _LogMessageForm extends StatefulWidget {
  const _LogMessageForm({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  _LogMessageFormState createState() => _LogMessageFormState();
}

class _LogMessageFormState extends State<_LogMessageForm> {
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
    if (message.isEmpty) {
      return;
    }

    widget.onSubmit(message);
    _messageController.clear();
    _messageFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(spacing),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            decoration:
            const InputDecoration.collapsed(hintText: 'Message'),
            autofocus: true,
            focusNode: _messageFocusNode,
            controller: _messageController,
            minLines: 1,
            maxLines: 10,
            style: Theme.of(context).textTheme.bodyMedium,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        const SizedBox(width: spacing / 2),
        TextButton(
          onPressed: _onSubmit,
          child: const Text('Write to log'),
        )
      ],
    ),
  );
}

abstract class LogMessage {
  String get id;
  DateTime get createdAt;
  String get message;
}

class CblLogMessage extends LogMessage {
  CblLogMessage(this.dict);

  final DictionaryInterface dict;

  @override
  String get id => dict.documentId;

  @override
  DateTime get createdAt => dict.value('createdAt')!;

  @override
  String get message => dict.value('message')!;

  String? get userId => dict.value('userId');
}

class User {
  User({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String email;
  final DateTime createdAt;

  factory User.fromDict(DictionaryInterface dict) {
    return User(
      id: dict.documentId,
      email: dict.value('email')!,
      createdAt: dict.value('createdAt')!,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': 'user',
      'email': email,
      'createdAt': createdAt,
    };
  }
}

class UserRepository {
  UserRepository(this.database, this.collection);

  final Database database;
  final Collection collection;

  Future<User> createUser(String email, String password) async {
    final doc = MutableDocument({
      'type': 'user',
      'email': email,
      'password': password, // In production, this should be hashed
      'createdAt': DateTime.now(),
    });
    await collection.saveDocument(doc);
    return User.fromDict(doc);
  }

  Future<User?> findUserByEmail(String email) async {
    // For now, just return null to allow registration
    // We'll implement proper querying later
    return null;
  }

  Future<User?> findUserByEmailAndPassword(String email, String password) async {
    final query = const QueryBuilder()
        .select(
      SelectResult.expression(Meta.id),
      SelectResult.property('email'),
      SelectResult.property('password'),
      SelectResult.property('createdAt'),
    )
        .from(DataSource.collection(collection))
        .where(
      Expression.property('type').equalTo(Expression.value('user')).and(
        Expression.property('email').equalTo(Expression.value(email)),
      ).and(
        Expression.property('password').equalTo(Expression.value(password)),
      ),
    );

    // For now, just return null to allow registration
    // We'll implement proper querying later
    return null;
  }

  Future<User?> findUserById(String userId) async {
    try {
      final doc = await collection.document(userId);
      if (doc != null) {
        return User.fromDict(doc);
      }
      return null;
    } catch (e) {
      print('Error finding user by ID: $e');
      return null;
    }
  }

  Stream<List<User>> allUsersStream() {
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
  }
}

class AuthManager {
  AuthManager(this.userRepository);

  final UserRepository userRepository;
  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<User?> register(String email, String password) async {
    try {
      // For now, skip duplicate check and just create user
      final user = await userRepository.createUser(email, password);
      _currentUser = user;
      return user;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      // For now, just create a new user if login fails
      // This allows us to test the basic functionality
      final user = await userRepository.createUser(email, password);
      _currentUser = user;
      return user;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<User?> getCurrentUser() async {
    // In a real app, you might want to persist the current user
    // For now, we'll return the in-memory user
    return _currentUser;
  }

  Future<void> logout() async {
    _currentUser = null;
  }
}

extension DictionaryDocumentIdExt on DictionaryInterface {
  String get documentId {
    final self = this;
    return self is Document ? self.id : self.value('id')!;
  }
}

class LogMessageRepository {
  LogMessageRepository(this.database, this.collection);

  final Database database;
  final Collection collection;

  Future<LogMessage> createLogMessage(String message, {String? userId}) async {
    final doc = MutableDocument({
      'type': 'logMessage',
      'createdAt': DateTime.now(),
      'message': message,
      if (userId != null) 'userId': userId,
    });
    await collection.saveDocument(doc);
    return CblLogMessage(doc);
  }

  Stream<List<LogMessage>> allLogMessagesStream() {
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
    Future(query.explain).then(print);

    return query.changes().asyncMap(
          (change) => change.results.asStream().map(CblLogMessage.new).toList(),
    );
  }

  Stream<List<LogMessage>> userLogMessagesStream(String userId) {
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
          (change) => change.results.asStream().map(CblLogMessage.new).toList(),
    );
  }
}

class SyncManager {
  late Replicator _replicator;
  late StreamController<ReplicatorStatus> _statusController;

  Stream<ReplicatorStatus> get statusStream => _statusController.stream;

  Future<void> initialize(Database database, List<Collection> collections) async {
    _statusController = StreamController<ReplicatorStatus>.broadcast();

    // Replace with your actual endpoint URL from Couchbase Cloud
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
    _replicator.changes().listen((change) {
      _statusController.add(change.status);
    });
  }

  void startSync() {
    _replicator.start();
  }

  void stopSync() {
    _replicator.stop();
  }

  void dispose() {
    _replicator.stop();
    _statusController.close();
  }
}

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

  database = await Database.openAsync('test_bucket');
  logMessages = await database.createCollection('logMessages');
  users = await database.createCollection('users');

  // Create indexes for logMessages
  await logMessages.createIndex(
    'type+createdAt',
    ValueIndex([
      ValueIndexItem.property('type'),
      ValueIndexItem.property('createdAt'),
    ]),
  );

  // Create indexes for users
  await users.createIndex(
    'type+email',
    ValueIndex([
      ValueIndexItem.property('type'),
      ValueIndexItem.property('email'),
    ]),
  );

  logMessageRepository = LogMessageRepository(database, logMessages);
  userRepository = UserRepository(database, users);
  authManager = AuthManager(userRepository);

  // Initialize sync manager with both collections
  syncManager = SyncManager();
  await syncManager.initialize(database, [logMessages, users]);
}