import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'welcome_screen.dart';
import 'disclaimer_screen.dart';
import 'home_screen.dart';
import 'diet_preferences_screen.dart';
import 'business_dashboard_screen.dart';

// controls where the user is routed based on auth + firestore state
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // listens to login/logout state
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // still loading auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF232323),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        // not logged in → go to welcome screen
        if (user == null) {
          return const WelcomeScreen();
        }

        // logged in → check firestore user document
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, snapshot) {
            // still loading user data
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF232323),
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};

            final role = data['role'];
            final managedVenueId = data['managedVenueId'];

            final disclaimerAccepted = data['disclaimerAccepted'] == true;

            final prefs = data['dietPreferences'];
            final hasPrefs = prefs is List && prefs.isNotEmpty;

            // business users go straight to the business dashboard
            if (role == 'business' &&
                managedVenueId != null &&
                managedVenueId.toString().trim().isNotEmpty) {
              return const BusinessDashboardScreen();
            }

            // disclaimer not accepted → show disclaimer
            if (!disclaimerAccepted) {
              return const DisclaimerScreen();
            }

            // disclaimer accepted but no preferences → show setup
            if (!hasPrefs) {
              return const DietPreferencesScreen();
            }

            // everything complete → go to app
            return const HomeScreen();
          },
        );
      },
    );
  }
}