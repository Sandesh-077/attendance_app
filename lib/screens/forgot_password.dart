import 'package:ca_attendance/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _sent = false;

  Future<void> _sendResetEmail() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _sent = false;
        _errorMessage = 'Enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _sent = false;
      _errorMessage = null;
    });

    try {
      await _authRepository.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _sent = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (error.code) {
          'invalid-email' => 'Enter a valid email address.',
          'user-not-found' => 'No account was found for this email.',
          'too-many-requests' => 'Too many attempts. Please try again later.',
          'network-request-failed' => 'Check your connection and try again.',
          _ =>
            error.message ??
                'Unable to send the reset email. Please try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _errorMessage = 'Unable to send the reset email. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Image(
                    image: AssetImage('assets/logo.png'),
                    height: 120,
                  ),
                  const SizedBox(height: 15.0),
                  Text(
                    'Forgot Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enter your email to reset your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) {
                      if (_errorMessage != null || _sent) {
                        setState(() {
                          _errorMessage = null;
                          _sent = false;
                        });
                      }
                    },
                    onSubmitted: (_) => _sendResetEmail(),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: const Icon(Icons.email),
                      border: const OutlineInputBorder(),
                      errorText: _errorMessage,
                    ),
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'If an account exists for this email, a password reset link has been sent. Check your inbox.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _sendResetEmail,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Send Reset Email'),
                        ),
                  const SizedBox(height: 30),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
