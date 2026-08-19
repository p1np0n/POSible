import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'models/employee_profile.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/cash_session_provider.dart';
import 'providers/store_provider.dart';
import 'screens/auth/lock_gate.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/pin_login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home/home_shell.dart';
import 'services/profile_repository.dart';

/// Color principal de la marca: naranja, con blanco y negro como base
/// neutra (en vez del morado/índigo que traía Flutter por defecto) — así
/// se ve más parecido a lo que se pidió, y se aplica en toda la app
/// (botones, barra de arriba, etc.) desde un solo lugar.
const _brandOrange = Color(0xFFFF7A1A);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(seedColor: _brandOrange, brightness: brightness).copyWith(
    primary: _brandOrange,
    onPrimary: Colors.white,
    surface: isDark ? const Color(0xFF121212) : Colors.white,
    onSurface: isDark ? Colors.white : Colors.black,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: _brandOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const PosibleApp());
}

class PosibleApp extends StatelessWidget {
  const PosibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CashSessionProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => AppPreferencesProvider()..load()),
      ],
      child: Consumer<AppPreferencesProvider>(
        builder: (context, prefs, _) {
          return MaterialApp(
            title: 'POSible',
            debugShowCheckedModeBanner: false,
            themeMode: prefs.darkMode ? ThemeMode.dark : ThemeMode.light,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStateStream;
  Future<EmployeeProfile?>? _profileFuture;
  String? _profileForUserId;
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  void _loadProfile(String userId) {
    _profileForUserId = userId;
    _profileFuture = ProfileRepository().getMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      builder: (context, snapshot) {
        // El enlace de "¿Olvidaste tu contraseña?" abre una sesión temporal
        // de recuperación: hay que pedir la contraseña nueva en vez de
        // dejar entrar directo a la app con ella.
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecovery = true;
        }

        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          _profileFuture = null;
          _profileForUserId = null;
          _passwordRecovery = false;
          // El login rápido con PIN es solo para el APK (Android) — en el
          // panel web siempre se usa correo y contraseña completos.
          final knownEmails = context.watch<AppPreferencesProvider>().knownEmails;
          return (kIsWeb || knownEmails.isEmpty) ? const LoginScreen() : const PinLoginScreen();
        }

        if (_passwordRecovery) {
          return ResetPasswordScreen(onDone: () => setState(() => _passwordRecovery = false));
        }

        if (_profileForUserId != session.user.id) {
          _loadProfile(session.user.id);
        }

        return FutureBuilder<EmployeeProfile?>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final profile = profileSnapshot.data;
            if (profile != null && profile.approved) {
              // El bloqueo automático (pedir PIN de nuevo) también es solo
              // para Android, ya que depende del login con PIN.
              return kIsWeb ? const HomeShell() : const LockGate(child: HomeShell());
            }
            return PendingApprovalScreen(
              onRetry: () => setState(() => _loadProfile(session.user.id)),
            );
          },
        );
      },
    );
  }
}
