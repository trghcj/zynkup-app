import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/firebase_options.dart';
import 'package:zynkup/features/auth/screens/login_screen.dart';
import 'package:zynkup/features/events/screens/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ADD THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INITIALIZE FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ONE-TIME: GENERATE INDEX LINKS (DELETE AFTER INDEXES ARE CREATED)
  await _generateFirestoreIndexes();

  runApp(const MyApp());
}

/// GENERATE INDEX LINKS FOR ALL CATEGORIES (RUN ONCE)
Future<void> _generateFirestoreIndexes() async {
  final categories = ['tech', 'cultural', 'sports', 'workshop'];
  print('\nGENERATING FIRESTORE INDEX LINKS...');

  for (var cat in categories) {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .where('category', isEqualTo: cat)
          .limit(1)
          .get();
    } catch (e) {
      if (e is FirebaseException && e.code == 'failed-precondition') {
        final link = e.message?.split('here: ').last ?? '';
        if (link.isNotEmpty) {
          print('\nINDEX FOR "$cat":');
          print(link);
          print('→ Paste in browser → Create Index\n');
        }
      } else {
        // rethrow unexpected errors so they're not silently swallowed
        rethrow;
      }
    }
  }

  print('INDEX LINKS GENERATED! Create all 4 → Then DELETE _generateFirestoreIndexes()');
  print('─────────────────────────────────────────────────────────────\n');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zynkup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // SHOW LOADER
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 16),
                  Text('Loading Zynkup...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        }

        // LOGGED IN → HOME
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // NOT LOGGED IN → LOGIN
        return const LoginScreen();
      },
    );
  }
}