import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_gate.dart';
import 'disclaimer_screen.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'widgets/auth_components.dart';

// create account screen
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  // text field controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;
  bool _googleReady = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // get google sign in ready
  Future<void> _initGoogle() async {
    if (_googleReady) return;

    await GoogleSignIn.instance.initialize();

    _googleReady = true;
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // create auth account
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = cred.user;
      if (user == null) throw Exception('no user returned');

      // create user doc
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'disclaimerAccepted': false,
        'role': 'user',
      });

      if (!mounted) return;

      // go to disclaimer
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DisclaimerScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'sign up failed';

      // common auth errors
      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email';
          break;
        case 'email-already-in-use':
          message = 'An account with this email already exists';
          break;
        case 'weak-password':
          message = 'Password must be at least 6 characters';
          break;
        default:
          message = e.message ?? 'sign up failed';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('sign up failed')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // google sign in
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await _initGoogle();

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;

      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('no id token');

      // firebase google credential
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCred.user;
      if (user == null) throw Exception('no user');

      final userDoc =
      FirebaseFirestore.instance.collection('users').doc(user.uid);

      final snapshot = await userDoc.get();

      // create user doc first time
      if (!snapshot.exists) {
        final name = (user.displayName ?? '').trim();
        final parts = name
            .split(' ')
            .where((part) => part.trim().isNotEmpty)
            .toList();

        await userDoc.set({
          'firstName': parts.isNotEmpty ? parts.first : '',
          'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
          'username': user.email?.split('@').first ?? 'user',
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'disclaimerAccepted': false,
          'role': 'user',
        });
      }

      if (!mounted) return;

      // go through auth gate
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _googleIcon() {
    return Image.asset(
      'assets/images/googleicon.png',
      height: 20,
      errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
    );
  }

  String? _requiredValidator(String? value) {
    return (value == null || value.trim().isEmpty) ? 'Required' : null;
  }

  String? _emailValidator(String? input) {
    final text = input?.trim() ?? '';

    if (text.isEmpty) return 'Required';

    // email format check
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(text)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  String? _passwordValidator(String? input) {
    final text = input ?? '';

    if (text.isEmpty) return 'Required';

    if (text.length < 6) return 'At least 6 characters';

    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Required';

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        children: [
          AuthHeader(
            title: 'Create an account',
            // back to welcome
            onBack: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              );
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    LabeledField(
                      label: 'First Name',
                      child: DarkTextField(
                        controller: _firstNameController,
                        hintText: 'First Name',
                        textInputAction: TextInputAction.next,
                        validator: _requiredValidator,
                      ),
                    ),

                    const SizedBox(height: 10),

                    LabeledField(
                      label: 'Last Name',
                      child: DarkTextField(
                        controller: _lastNameController,
                        hintText: 'Last Name',
                        textInputAction: TextInputAction.next,
                        validator: _requiredValidator,
                      ),
                    ),

                    const SizedBox(height: 10),

                    LabeledField(
                      label: 'Email Address',
                      child: DarkTextField(
                        controller: _emailController,
                        hintText: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _emailValidator,
                      ),
                    ),

                    const SizedBox(height: 10),

                    LabeledField(
                      label: 'Username',
                      child: DarkTextField(
                        controller: _usernameController,
                        hintText: 'Username',
                        textInputAction: TextInputAction.next,
                        validator: _requiredValidator,
                      ),
                    ),

                    const SizedBox(height: 10),
                    LabeledField(
                      label: 'Password',
                      child: DarkTextField(
                        controller: _passwordController,
                        hintText: 'Password',
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.next,
                        validator: _passwordValidator,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hidePassword = !_hidePassword;
                            });
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    LabeledField(
                      label: 'Confirm Password',
                      child: DarkTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm Password',
                        obscureText: _hideConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _signUp();
                        },
                        validator: _confirmPasswordValidator,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hideConfirmPassword = !_hideConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _hideConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // create account button
                    PrimaryPillButton(
                      text: 'Create account',
                      loading: _isLoading,
                      onPressed: _signUp,
                    ),

                    const SizedBox(height: 10),

                    // google button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          foregroundColor: Colors.white,
                        ),
                        icon: _googleIcon(),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already got an account? ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Log in here',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}