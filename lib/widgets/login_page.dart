import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_manager.dart';
import '../utils/constants.dart';
import '../main.dart';

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
        if (_isRegistering) {
          // After successful registration, switch to login mode
          setState(() {
            _isRegistering = false;
            _errorMessage = 'Registration successful! Please login with your credentials.';
          });
          // Clear the form
          _emailController.clear();
          _passwordController.clear();
          // Clear success message after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _errorMessage = null;
              });
            }
          });
        } else {
          // After successful login, go to home screen
          widget.onLoginSuccess(user);
        }
      } else {
        setState(() {
          _errorMessage = _isRegistering 
              ? 'Registration failed. User might already exist.'
              : 'Invalid email or password.';
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
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
      title: Text(_isRegistering ? 'Create Account' : 'Sign In'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(AppConstants.spacing),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEmailField(),
            const SizedBox(height: AppConstants.spacing),
            _buildPasswordField(),
            const SizedBox(height: AppConstants.spacing),
            if (_errorMessage != null) _buildErrorMessage(),
            _buildSubmitButton(),
            const SizedBox(height: AppConstants.spacing / 2),
            _buildToggleButton(),
          ],
        ),
      ),
    ),
  );

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: _validateEmail,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(),
      ),
      obscureText: true,
      validator: _validatePassword,
    );
  }

  Widget _buildErrorMessage() {
    final isSuccessMessage = _errorMessage!.contains('successful');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacing),
      child: Text(
        _errorMessage!,
        style: TextStyle(
          color: isSuccessMessage ? Colors.green : Colors.red,
          fontWeight: isSuccessMessage ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        child: _isLoading
            ? const CircularProgressIndicator()
            : Text(_isRegistering ? 'Create Account' : 'Sign In'),
      ),
    );
  }

  Widget _buildToggleButton() {
    return TextButton(
      onPressed: _isLoading
          ? null
          : () => setState(() => _isRegistering = !_isRegistering),
      child: Text(_isRegistering
          ? 'Already have an account? Login'
          : 'Don\'t have an account? Register'),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }
} 