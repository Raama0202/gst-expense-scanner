import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gst_expense_scanner/core/config/server_config.dart';
import 'package:gst_expense_scanner/core/constants/app_constants.dart';
import 'package:gst_expense_scanner/features/auth/presentation/providers/auth_providers.dart';
import 'package:gst_expense_scanner/features/settings/presentation/server_endpoint_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _rememberLogin = true;
  bool _submitting = false;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  String? _validateMobile(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return 'Enter a valid 10-digit Indian mobile number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Mobile number must start with 6, 7, 8, or 9';
    }
    return null;
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final mobile = _mobileController.text.replaceAll(RegExp(r'\D'), '');
    setState(() => _submitting = true);

    await ref.read(authStateProvider.notifier).sendOtp(mobile);

    if (!mounted) return;
    setState(() => _submitting = false);

    final authState = ref.read(authStateProvider);
    if (authState is AuthErrorState) {
      _showMessage(authState.message);
      ref.read(authStateProvider.notifier).clearError();
      return;
    }

    context.push(
      '/otp',
      extra: {
        'mobile': mobile,
        'rememberLogin': _rememberLogin,
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final loading = _submitting || authState is AuthAuthenticating;

    return Scaffold(
      body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your registered mobile number',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Mobile number',
                          prefixText: '+91 ',
                          hintText: '9876543210',
                        ),
                        validator: _validateMobile,
                        onFieldSubmitted: (_) => _sendOtp(),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: _rememberLogin,
                        onChanged: loading
                            ? null
                            : (value) {
                                setState(() => _rememberLogin = value ?? true);
                              },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Remember login on this device'),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: loading ? null : _sendOtp,
                        child: loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send OTP'),
                      ),
                      if (ServerConfig.canOverride) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: loading
                              ? null
                              : () => ServerEndpointDialog.show(context),
                          icon: const Icon(Icons.dns_outlined, size: 18),
                          label: Text('Server: ${ServerConfig.displayHost}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}
