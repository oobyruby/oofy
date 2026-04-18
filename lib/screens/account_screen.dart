import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'widgets/app_top_bar.dart';

// account screen
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // loading states
  bool _loading = true;
  bool _deleting = false;

  // user info
  String _username = '';
  String _email = '';

  // fake password display
  final String _passwordMask = '************';

  @override
  void initState() {
    super.initState();

    // load user data
    _loadUserData();
  }

  // fallback text if empty
  String get _displayUsername => _username.trim().isEmpty ? '-' : _username;
  String get _displayEmail => _email.trim().isEmpty ? '-' : _email;

  Future<void> _goToLogin() async {
    if (!mounted) return;

    // go back to login and clear old screens
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
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
        width: 220,
        backgroundColor: const Color(0xFF3B3B3B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    // send back if no user is signed in
    if (user == null) {
      await _goToLogin();
      return;
    }

    try {
      // get user info from firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _username = (data['username'] ?? '').toString();
        _email = (data['email'] ?? user.email ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      // use auth email if firestore fails
      if (!mounted) return;

      setState(() {
        _email = user.email ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    // show delete confirmation
    await showDialog<void>(
      context: context,
      barrierDismissible: !_deleting,
      builder: (dialogContext) {
        return _DeleteAccountDialog(
          deleting: _deleting,
          onConfirm: () async {
            Navigator.of(dialogContext).pop();
            await _deleteAccount();
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _deleting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final uid = user.uid;

      // find all reviews by this user
      final reviewQuery = await firestore
          .collectionGroup('reviews')
          .where('uid', isEqualTo: uid)
          .get();

      final batch = firestore.batch();

      // delete their reviews
      for (final doc in reviewQuery.docs) {
        batch.delete(doc.reference);
      }

      // delete user doc
      batch.delete(firestore.collection('users').doc(uid));

      // save all deletes
      await batch.commit();

      // delete auth account
      await user.delete();

      if (!mounted) return;

      // send user back to login
      await _goToLogin();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // firebase may ask for a recent login first
      var message = 'Failed to delete account.';
      if (e.code == 'requires-recent-login') {
        message = 'Log out and back in before deleting your account.';
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

  void _showComingSoon(String fieldName) {
    // placeholder for edit options
    _showPillSnackbar('$fieldName editing coming soon');
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1E1E1E);
    const soft = Color(0xFF2F2F2F);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
        // loading spinner
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              AppTopBar(
                onLeftTap: () => Navigator.pop(context),
                rightIcon: Icons.person_rounded,
              ),
              const SizedBox(height: 18),

              const _ScreenTitlePill(title: 'Account'),

              const SizedBox(height: 28),

              const _ProfilePicturePlaceholder(),

              const SizedBox(height: 12),

              // profile picture option for later
              const Text(
                'Change Profile Picture',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 42),

              _AccountRow(
                label: 'Username: $_displayUsername',
                onEdit: () => _showComingSoon('Username'),
              ),

              const SizedBox(height: 22),

              _AccountRow(
                label: 'Password: $_passwordMask',
                onEdit: () => _showComingSoon('Password'),
              ),

              const SizedBox(height: 22),

              _AccountRow(
                label: 'Email: $_displayEmail',
                onEdit: () => _showComingSoon('Email'),
              ),

              const Spacer(),

              // delete account button
              _DeleteAccountButton(
                deleting: _deleting,
                backgroundColor: soft,
                onTap: _deleting ? null : _showDeleteAccountDialog,
              ),

              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}