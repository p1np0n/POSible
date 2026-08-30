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
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  enableVerboseErrorDisplay();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const PosibleApp());
}

/// TEMPORAL (para diagnosticar el bug de Reportes en blanco): por defecto,
/// en el build de producción Flutter reemplaza cualquier widget que falle
/// al construirse por una caja vacía, sin mostrar ni loguear el error —
/// así es indistinguible de "no hay nada". Esto hace que ese error se vea
/// en pantalla (y en la consola del navegador) en vez de desaparecer en
/// silencio. Se quita en cuanto se encuentre la causa real.
void enableVerboseErrorDisplay() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError capturado: ${details.exception}\n${details.stack}');
  };
  ErrorWidget.builder = (details) => Material(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'Error al construir un widget:\n\n${details.exception}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      );
}

/// [title] y [home] permiten reutilizar esta misma app (login, providers,
/// tema) para un punto de entrada distinto — ver lib/main_info_admin.dart,
/// que compila un APK aparte con solo InfoAdminShell como pantalla
/// principal, sin duplicar todo el flujo de autenticación.
class PosibleApp extends StatelessWidget {
  final String title;
  final Widget home;

  const PosibleApp({super.key, this.title = 'POSible', this.home = const HomeShell()});

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
            title: title,
            debugShowCheckedModeBanner: false,
            themeMode: prefs.darkMode ? ThemeMode.dark : ThemeMode.light,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            home: AuthGate(home: home),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final Widget home;

  const AuthGate({super.key, required this.home});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStateStream;
  Future<EmployeeProfile?>? _profileFuture;
  String? _profileForUserId;
  bool _passwordRecovery = false;
  bool _storeLoadRequested = false;

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
              // CurrentStore.id (usado por varios repositorios, ej. los
              // reportes) se llena recién acá — antes solo lo pedía
              // HomeShell, así que un "home" distinto (ver
              // lib/main_info_admin.dart) se quedaba sin tienda asignada.
              final store = context.watch<StoreProvider>();
              if (!store.loaded) {
                if (!_storeLoadRequested) {
                  _storeLoadRequested = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) => context.read<StoreProvider>().load());
                }
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              // El bloqueo automático (pedir PIN de nuevo) también es solo
              // para Android, ya que depende del login con PIN.
              return kIsWeb ? widget.home : LockGate(child: widget.home);
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
