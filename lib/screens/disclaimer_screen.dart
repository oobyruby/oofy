import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_gate.dart';

// disclaimer screen
class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  // loading state
  bool _isLoading = false;

  Future<void> _acceptDisclaimer() async {
    // start loading
    setState(() => _isLoading = true);

    try {
      // current user
      final user = FirebaseAuth.instance.currentUser;

      // no user
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // save acceptance
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'disclaimerAccepted': true,
          'disclaimerAcceptedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      // go to app
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } catch (_) {
      // save failed
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save disclaimer acceptance')),
      );
    } finally {
      // stop loading
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // scroll area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 28, bottom: 16),
                  child: Column(
                    children: [
                      // logo
                      Image.asset(
                        'assets/images/oofy_logo.png',
                        width: 260,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Other Options For You',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 0.4,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),

                      // mascot
                      Image.asset(
                        'assets/images/oofy.png',
                        height: 210,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 24),

                      // disclaimer box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          "Disclaimer: We do our best to keep everything accurate and helpful, "
                              "but we can’t guarantee that any venue will be completely safe for every dietary need. "
                              "Please check with the venue directly to make sure it’s safe for your needs, "
                              "and choose what feels right for you.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _acceptDisclaimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F1F1F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}