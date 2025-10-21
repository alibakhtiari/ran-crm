import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/call_log_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_screen.dart';
import 'services/background_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background sync service
  try {
    await BackgroundSyncService.initialize();
    print('✅ Background sync service initialized');
  } catch (e) {
    print('❌ Failed to initialize background sync: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => CallLogProvider()),
      ],
      child: MaterialApp(
        title: 'RAN CRM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthGate(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/admin': (context) => const AdminScreen(),
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        switch (authProvider.status) {
          case AuthStatus.initial:
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          case AuthStatus.authenticated:
            // Navigate to home screen after authentication is confirmed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/home');
            });
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          case AuthStatus.unauthenticated:
          case AuthStatus.loading:
            return const LoginScreen();
        }
      },
    );
  }
}
