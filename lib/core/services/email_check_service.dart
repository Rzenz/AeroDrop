import 'dart:async';

import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// The check-email Edge Function's verdict on an address
/// (supabase/functions/check-email, migration 34).
class EmailCheckResult {
  const EmailCheckResult({
    required this.ok,
    this.reason,
    this.message,
    this.suggestion,
    this.unchecked = false,
  });

  /// Allowed. Also true when the check could not run ([unchecked]): the
  /// emailed sign-up code still proves the inbox, and an outage must never
  /// stop real people from registering.
  final bool ok;

  /// invalid | disposable | typo | no_domain | no_mail
  final String? reason;

  /// Ready to show to the person.
  final String? message;

  /// For a typo, the address they most likely meant.
  final String? suggestion;

  final bool unchecked;

  static const allowedUnchecked = EmailCheckResult(ok: true, unchecked: true);

  /// Reads the function's JSON body. Anything unexpected counts as unchecked.
  factory EmailCheckResult.fromResponse(Object? data) {
    if (data is! Map || data['ok'] is! bool) return allowedUnchecked;
    return EmailCheckResult(
      ok: data['ok'] as bool,
      reason: data['reason'] as String?,
      message: data['message'] as String?,
      suggestion: data['suggestion'] as String?,
      unchecked: data['unchecked'] == true,
    );
  }

  /// The message for a refused address, with a fallback.
  String get errorText =>
      message ?? "This email address can't receive mail. Please check it.";
}

/// Calls check-email. Never throws: a failed call is [EmailCheckResult.allowedUnchecked].
Future<EmailCheckResult> checkEmailIsReal(String normalizedEmail) async {
  try {
    final res = await SupabaseService.client.functions
        .invoke('check-email', body: {'email': normalizedEmail})
        .timeout(const Duration(seconds: 8));
    return EmailCheckResult.fromResponse(res.data);
  } catch (e) {
    debugPrint('check-email unavailable, continuing: $e');
    return EmailCheckResult.allowedUnchecked;
  }
}
