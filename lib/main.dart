import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loan_app_new/providers/auth_provider.dart';
import 'package:loan_app_new/providers/loan_provider.dart';
import 'package:loan_app_new/screens/splash_screen.dart';
import 'package:loan_app_new/screens/login_screen.dart';
import 'package:loan_app_new/screens/dashboard_screen.dart';
import 'package:loan_app_new/screens/guarantor_screen.dart';
import 'package:loan_app_new/utils/theme.dart';

// 🔑 ADD YOUR SUPABASE CREDENTIALS HERE
// Get these from: https://app.supabase.com/project/_/settings/api
const String supabaseUrl = 'https://adxjesmeaqmykbpjulhb.supabase.co';
const String supabaseAnonKey = 'sb_publishable_NKnTQlfZGEitGFt9MAk63A_Iq569Afn';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    print('✅ Supabase initialized successfully');
  } catch (e) {
    print('❌ Supabase initialization failed: $e');
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
        ChangeNotifierProvider(create: (_) => LoanProvider()),
      ],
      child: MaterialApp(
        title: 'Loan App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/guarantor': (context) => GuarantorScreen(),
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const Scaffold(
              body: Center(
                child: Text('Page not found'),
              ),
            ),
          );
        },
      ),
    );
  }
}