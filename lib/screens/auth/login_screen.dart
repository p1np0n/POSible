import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/app_preferences_provider.dart';
import 'create_store_screen.dart';

// URL del panel publicado en GitHub Pages — se usa como destino del enlace
// de recuperación de contraseña cuando la app corre como APK (ahí no hay
// forma de saber la URL "actual" como en la web).
const _webAppUrl = 'https://p1np0n.github.io/POSible/';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storeCodeController = TextEditingController();
  bool _loading = false;
  bool _isSignUp = false;
  String? _errorMessage;
  String? _infoMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      final email = _emailController.text.trim();
      if (_isSignUp) {
        await auth.signUp(
          email: email,
          password: _passwordController.text,
          data: {'mode': 'join_store', 'store_code': _storeCodeController.text.trim()},
        );
      } else {
        await auth.signInWithPassword(email: email, password: _passwordController.text);
      }
      // El login rápido con PIN es solo para el APK; en web no hace falta
      // recordar el correo en este dispositivo.
      if (!kIsWeb && mounted) await context.read<AppPreferencesProvider>().rememberEmail(email);
      // Si esta pantalla se abrió desde "Usar otra cuenta" en el acceso con
      // PIN, la cerramos para que se vea la app ya con la nueva sesión.
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Error de conexión. Revisa tu configuración de Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? Uri.base.origin + Uri.base.path : _webAppUrl,
      );
      if (mounted) {
        setState(() {
          _infoMessage =
              'Si ese correo tiene una cuenta, te enviamos un enlace para elegir una contraseña nueva. Revisa también spam.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'No se pudo enviar el correo. Intenta de nuevo.');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _storeCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.point_of_sale, size: 64, color: Colors.indigo),
                  const SizedBox(height: 8),
                  Text(
                    'POSible',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
                    validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu correo' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      helperText: kIsWeb
                          ? null
                          : 'Usa 4 dígitos numéricos para poder entrar rápido con PIN después',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.length < 4) ? 'Mínimo 4 caracteres' : null,
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _storeCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Código de tienda',
                        helperText: 'Te lo da el dueño de la tienda a la que te vas a unir',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Ingresa el código de tu tienda' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_infoMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_infoMessage!, style: const TextStyle(color: Colors.green)),
                    ),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isSignUp ? 'Crear cuenta' : 'Iniciar sesión'),
                  ),
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = null;
                              _infoMessage = null;
                            }),
                    child: Text(_isSignUp
                        ? '¿Ya tienes cuenta? Inicia sesión'
                        : '¿Eres empleado nuevo? Crea tu cuenta'),
                  ),
                  if (!_isSignUp)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CreateStoreScreen()),
                              ),
                      child: const Text('¿Vas a abrir una tienda nueva? Créala aquí'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
