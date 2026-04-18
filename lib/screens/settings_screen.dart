import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'widgets/app_top_bar.dart';

// settings screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // delete state
  bool _deleting = false;

  void _goToHome(BuildContext context) {
    // go to home tab
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(initialIndex: 0),
      ),
    );
  }

  void _goToProfile(BuildContext context) {
    // go to profile tab
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(initialIndex: 3),
      ),
    );
  }

  Future<void> _goToLogin(BuildContext context) async {
    if (!mounted) return;

    // go to login
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _signOut(BuildContext context) async {
    // sign out
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    // placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

  void _showPillSnackbar(String message) {
    if (!mounted) return;

    // app snackbar style
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        width: 250,
        backgroundColor: const Color(0xFF3B3B3B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool hidePassword = true;

    // delete dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: !_deleting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Delete account?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Are you sure you want to delete your account?\n\nThis cannot be restored.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // password field
                    TextFormField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      enabled: !_deleting,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Confirm password',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1F1F1F),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your password';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _deleting
                      ? null
                      : () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _deleting
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) return;

                    Navigator.of(dialogContext).pop();

                    await _deleteAccount(
                      password: passwordController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3A3A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Yes, delete',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
  }

  Future<void> _deleteAccount({required String password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email?.trim() ?? '';

    // email and password only
    if (email.isEmpty) {
      _showPillSnackbar('This account cannot be confirmed with a password');
      return;
    }

    setState(() => _deleting = true);

    try {
      // reauthenticate first
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      final firestore = FirebaseFirestore.instance;
      final uid = user.uid;

      // find user reviews
      final reviewQuery = await firestore
          .collectionGroup('reviews')
          .where('uid', isEqualTo: uid)
          .get();

      final batch = firestore.batch();

      // delete reviews
      for (final doc in reviewQuery.docs) {
        batch.delete(doc.reference);
      }

      // delete user doc
      batch.delete(firestore.collection('users').doc(uid));

      // save deletes
      await batch.commit();

      // delete auth account
      await user.delete();

      if (!mounted) return;

      // go back to login
      await _goToLogin(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Failed to delete account.';

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect password.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        case 'user-mismatch':
          message = 'Could not confirm this account.';
          break;
        default:
          message = e.message ?? 'Failed to delete account.';
      }

      _showPillSnackbar(message);
    } catch (_) {
      if (!mounted) return;
      _showPillSnackbar('Failed to delete account');
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1E1E1E);
    const card = Color(0xFF2A2A2A);
    const pill = Color(0xFF3A3A3A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              AppTopBar(
                onLeftTap: () => _goToHome(context),
                onRightTap: () => _goToProfile(context),
                rightIcon: Icons.person_rounded,
              ),
              const SizedBox(height: 18),

              // settings title
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: pill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // settings items
              _SettingsItem(
                icon: Icons.person_outline,
                label: 'Account',
                color: card,
                onTap: () => _showComingSoon(context, 'Account'),
              ),
              const SizedBox(height: 12),

              _SettingsItem(
                icon: Icons.tune_rounded,
                label: 'Preferences',
                color: card,
                onTap: () => _showComingSoon(context, 'Preferences'),
              ),
              const SizedBox(height: 12),

              _SettingsItem(
                icon: Icons.help_outline,
                label: 'Help',
                color: card,
                onTap: () => _showComingSoon(context, 'Help'),
              ),
              const SizedBox(height: 12),

              _SettingsItem(
                icon: Icons.lock_outline,
                label: 'Privacy',
                color: card,
                onTap: () => _showComingSoon(context, 'Privacy'),
              ),

              const Spacer(),

              // delete button
              _DeleteAccountPill(
                deleting: _deleting,
                onTap: _deleting ? null : _showDeleteAccountDialog,
              ),
              const SizedBox(height: 12),

              // sign out button
              _SignOutPill(
                onTap: _deleting ? null : () => _signOut(context),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // settings row
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountPill extends StatelessWidget {
  final VoidCallback? onTap;
  final bool deleting;

  const _DeleteAccountPill({
    required this.onTap,
    required this.deleting,
  });

  @override
  Widget build(BuildContext context) {
    // delete button
    return SizedBox(
      width: 190,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A2A2A),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: deleting
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Text(
          'Delete Account',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SignOutPill extends StatelessWidget {
  final VoidCallback? onTap;

  const _SignOutPill({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // sign out button
    return SizedBox(
      width: 190,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A2A2A),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: const Text(
          'Sign Out',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}