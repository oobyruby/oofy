import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_gate.dart';
import 'create_account_screen.dart';
import 'welcome_screen.dart';
import 'widgets/auth_components.dart';

// login screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // form key
  final _formKey = GlobalKey<FormState>();

  // text field controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ui state
  bool _hidePassword = true;
  bool _isLoading = false;
  bool _googleReady = false;

  @override
  void dispose() {
    // dispose controllers
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // get google sign in ready
  Future<void> _initGoogle() async {
    if (_googleReady) return;

    await GoogleSignIn.instance.initialize();

    _googleReady = true;
  }

  Future<void> _logIn() async {
    // stop if form is invalid
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // sign in with firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // go through auth gate
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';

      // common login errors
      switch (e.code) {
        case 'invalid-email':
          message = 'Email is incorrect';
          break;
        case 'wrong-password':
          message = 'Password is incorrect';
          break;
        case 'user-not-found':
          message = 'Email is incorrect';
          break;
        case 'invalid-credential':
          message = 'Email is incorrect';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'Log in failed';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      // fallback error
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
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
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

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
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // google icon
  Widget _googleIcon() {
    return Image.asset(
      'assets/images/googleicon.png',
      height: 20,
      errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        children: [
          AuthHeader(
            title: 'Log in',
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
                    const SizedBox(height: 34),

                    LabeledField(
                      label: 'Email Address',
                      child: DarkTextField(
                        controller: _emailController,
                        hintText: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final value = v?.trim() ?? '';

                          // email required
                          if (value.isEmpty) return 'Required';

                          // email format check
                          final emailRegex =
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Email is incorrect';
                          }

                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    LabeledField(
                      label: 'Password',
                      child: DarkTextField(
                        controller: _passwordController,
                        hintText: 'Password',
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          // submit on enter
                          if (!_isLoading) _logIn();
                        },
                        suffixIcon: IconButton(
                          onPressed: () {
                            // show or hide password
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
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // placeholder
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset coming soon'),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // login button
                    PrimaryPillButton(
                      text: 'Log in',
                      loading: _isLoading,
                      onPressed: _logIn,
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

                    // create account link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
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
                                builder: (_) => const CreateAccountScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Create one here',
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