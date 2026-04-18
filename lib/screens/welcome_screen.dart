import 'package:flutter/material.dart';
import 'create_account_screen.dart';

// welcome screen
// first screen shown when the user opens the app
// if they are not already signed in
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // pushes content down a bit
              const Spacer(flex: 2),

              // app logo
              Image.asset(
                'assets/images/oofy_logo.png',
                width: 260,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 10),

              // short tagline under the logo
              const Text(
                'Other Options For You',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 0.4,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 26),

              // main character image
              Image.asset(
                'assets/images/oofy.png',
                height: 190,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 26),

              // takes user to account creation
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // replaces this screen so the user does not return to it
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateAccountScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F1F1F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // balances the layout near the bottom
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}