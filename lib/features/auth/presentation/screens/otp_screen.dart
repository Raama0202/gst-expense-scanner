import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gst_expense_scanner/core/constants/app_constants.dart';
import 'package:gst_expense_scanner/features/auth/presentation/providers/auth_providers.dart';
import 'package:gst_expense_scanner/features/sync/presentation/sync_providers.dart';
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.mobile,
    required this.rememberLogin,
  });

  final String mobile;
  final bool rememberLogin;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _resendTimer;
  int _secondsRemaining = AppConstants.otpResendSeconds;
  bool _verifying = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = AppConstants.otpResendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  String _maskMobile(String mobile) {
    if (mobile.length < 4) return mobile;
    return '${mobile.substring(0, 2)}******${mobile.substring(mobile.length - 2)}';
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != AppConstants.otpLength) {
      _showMessage('Enter the ${AppConstants.otpLength}-digit OTP');
      return;
    }

    setState(() => _verifying = true);
    final ok = await ref.read(authStateProvider.notifier).verifyOtp(
          mobile: widget.mobile,
          otp: otp,
          rememberLogin: widget.rememberLogin,
        );
    if (!mounted) return;
    setState(() => _verifying = false);

    if (ok) {
      await ref.read(syncStatusProvider.notifier).startEngine();
      if (!mounted) return;
      context.go('/home');
      return;
    }
    final authState = ref.read(authStateProvider);
    if (authState is AuthErrorState) {
      _showMessage(authState.message);
      ref.read(authStateProvider.notifier).clearError();
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _resending) return;

    setState(() => _resending = true);
    await ref.read(authStateProvider.notifier).sendOtp(widget.mobile);
    if (!mounted) return;
    setState(() => _resending = false);

    final authState = ref.read(authStateProvider);
    if (authState is AuthErrorState) {
      _showMessage(authState.message);
      ref.read(authStateProvider.notifier).clearError();
      return;
    }

    _otpController.clear();
    _startResendTimer();
    _showMessage('OTP sent again');
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
    final loading = _verifying || authState is AuthAuthenticating;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter OTP',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a code to +91 ${_maskMobile(widget.mobile)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _otpController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: 12,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(AppConstants.otpLength),
                  ],
                  decoration: const InputDecoration(
                    hintText: '000000',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : _verify,
                  child: loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify & continue'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: (_secondsRemaining > 0 || _resending)
                      ? null
                      : _resendOtp,
                  child: _resending
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _secondsRemaining > 0
                              ? 'Resend OTP in ${_secondsRemaining}s'
                              : 'Resend OTP',
                        ),
                ),
                const Spacer(),
                Text(
                  'Did not receive the code? Check SMS or tap resend after the timer.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
