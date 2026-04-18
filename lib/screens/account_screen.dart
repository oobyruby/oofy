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

  void _goToLogin() {
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
        width: 260,
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
      _goToLogin();
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
    // wait for dialog to close first
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: !_deleting,
      builder: (dialogContext) {
        return _DeleteAccountDialog(
          deleting: _deleting,
          onConfirm: () {
            Navigator.of(dialogContext).pop(true);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop(false);
          },
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() => _deleting = true);
    }

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

      // save firestore deletes first
      await batch.commit();

      // delete auth account
      await user.delete();

      if (!mounted) return;

      // send user back to login
      _goToLogin();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // firebase may ask for a recent login first
      var message = 'Failed to delete account';
      if (e.code == 'requires-recent-login') {
        message = 'Log out and back in before deleting your account';
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

// title pill
class _ScreenTitlePill extends StatelessWidget {
  final String title;

  const _ScreenTitlePill({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// profile image placeholder
class _ProfilePicturePlaceholder extends StatelessWidget {
  const _ProfilePicturePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white70,
        size: 52,
      ),
    );
  }
}

// account info row
class _AccountRow extends StatelessWidget {
  final String label;
  final VoidCallback onEdit;

  const _AccountRow({
    required this.label,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onEdit,
            splashRadius: 22,
            icon: const Icon(
              Icons.edit_rounded,
              color: Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// delete button
class _DeleteAccountButton extends StatelessWidget {
  final bool deleting;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _DeleteAccountButton({
    required this.deleting,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: deleting
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
                : const Text(
              'Delete Account',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// delete dialog
class _DeleteAccountDialog extends StatelessWidget {
  final bool deleting;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _DeleteAccountDialog({
    required this.deleting,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2B2B2B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      title: const Text(
        'Delete account?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: const Text(
        'This will permanently remove your account and reviews.',
        style: TextStyle(
          color: Colors.white70,
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: deleting ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: deleting ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}