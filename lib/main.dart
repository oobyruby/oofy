import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';   // handles login state routing

Future<void> main() async {
  // ensures flutter is ready before firebase init
  WidgetsFlutterBinding.ensureInitialized();

  // initialise firebase with platform config
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleSignIn.instance.initialize();

  // start the app
  runApp(const OofyApp());
}

// root widget of the app
class OofyApp extends StatelessWidget {
  const OofyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Oofy',

      // using material 3 styling
      theme: ThemeData(useMaterial3: true),

      // auth gate decides where user goes (login / app)
      home: const AuthGate(),
    );
  }
}