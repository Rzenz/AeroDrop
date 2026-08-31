import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../widgets/neu_feedback.dart';

/// Asks the user to confirm signing out, then does it.
///
/// The sign-out runs inside the dialog rather than after it, so the confirm
/// button can show progress and a failure can be reported in place. The
/// previous version closed the dialog first and then raised a snackbar, which
/// meant the error arrived on whatever screen happened to be underneath.
Future<void> showLogoutConfirmation(BuildContext context, WidgetRef ref) async {
  final loggedOut = await showNeuConfirm(
    context,
    title: 'Log Out',
    message: 'Are you sure you want to log out of your account?',
    confirmLabel: 'Log Out',
    cancelLabel: 'Cancel',
    destructive: true,
    icon: Icons.logout_rounded,
    onConfirm: () async {
      final success = await ref.read(authProvider.notifier).logout();
      return success ? null : 'Could not log out. Check your connection.';
    },
  );

  if (loggedOut && context.mounted) {
    context.go('/login');
  }
}
