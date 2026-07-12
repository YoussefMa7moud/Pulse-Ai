import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/theme.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/animated_background.dart';
import '../../../data/database_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  String _cleanSupabaseError(sb.AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    } else if (msg.contains('email already in use') || msg.contains('user already exists')) {
      return 'This email is already registered. Try logging in.';
    } else if (msg.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    } else if (msg.contains('invalid email')) {
      return 'Please enter a valid email address.';
    } else if (msg.contains('network') || msg.contains('connection')) {
      return 'Network error. Check your connection and try again.';
    }
    return e.message; // fallback
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final db = ref.read(databaseProvider);

    try {
      if (_isLogin) {
        // Sign In
        await db.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // Sign Up
        await db.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Update profile name immediately if registration is successful
        if (db.client.auth.currentUser != null) {
          final profile = await db.getUserProfile();
          if (_nameController.text.trim().isNotEmpty) {
            profile.name = _nameController.text.trim();
            await db.saveUserProfile(profile);
          }
        }
      }

      if (mounted) {
        // Redirect will happen automatically via app_router auth state listener
        context.go('/');
      }
    } on sb.AuthException catch (e) {
      setState(() {
        _errorMessage = _cleanSupabaseError(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(_fadeAnimation),
                child: GlassContainer(
                  padding: const EdgeInsets.all(32),
                  borderColor: PulseTheme.accent.withOpacity(0.2),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 64,
                            color: PulseTheme.recoveryLow,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _isLogin ? 'PULSE AI' : 'JOIN PULSE AI',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _isLogin
                                ? 'Log in to synchronize your cardiovascular stats'
                                : 'Create an account to start syncing health connect metrics',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: PulseTheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Error Banner
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: PulseTheme.recoveryLow.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: PulseTheme.recoveryLow.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: PulseTheme.recoveryLow, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: PulseTheme.recoveryLow, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Name field (Sign Up only)
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'NAME',
                              labelStyle: TextStyle(color: PulseTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                              prefixIcon: Icon(Icons.person_outline, color: PulseTheme.secondary),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.surfaceLight)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.accent)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Please enter your name';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'EMAIL',
                            labelStyle: TextStyle(color: PulseTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            prefixIcon: Icon(Icons.email_outlined, color: PulseTheme.secondary),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.surfaceLight)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.accent)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter your email';
                            final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailReg.hasMatch(val.trim())) return 'Please enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'PASSWORD',
                            labelStyle: TextStyle(color: PulseTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            prefixIcon: Icon(Icons.lock_outline, color: PulseTheme.secondary),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.surfaceLight)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.accent)),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Please enter your password';
                            if (val.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password (Sign Up only)
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'CONFIRM PASSWORD',
                              labelStyle: TextStyle(color: PulseTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                              prefixIcon: Icon(Icons.lock_reset, color: PulseTheme.secondary),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.surfaceLight)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: PulseTheme.accent)),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please confirm your password';
                              if (val != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PulseTheme.accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            shadowColor: PulseTheme.accent.withOpacity(0.3),
                            elevation: 8,
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14),
                                ),
                        ),

                        const SizedBox(height: 20),

                        // Toggle Mode Button
                        TextButton(
                          onPressed: _isLoading ? null : _toggleAuthMode,
                          child: Text(
                            _isLogin ? "Don't have an account? Sign up" : 'Already have an account? Sign in',
                            style: const TextStyle(color: PulseTheme.secondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
