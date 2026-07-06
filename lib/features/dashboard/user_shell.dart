import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/aerodrop_bottom_navigation.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';

class UserShell extends ConsumerStatefulWidget {
  final Widget child;
  const UserShell({super.key, required this.child});

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _springController;
  Timer? _statusCheckTimer;
  bool _accountStatusDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Register app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Periodic check every 10 seconds on user side
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAccountStatus());

    // Initial check when user dashboard opens
    Future.microtask(_checkAccountStatus);
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _springController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccountStatus();
    }
  }

  Future<void> _checkAccountStatus() async {
    if (_accountStatusDialogShowing) return;
    if (!SupabaseService.isConfigured) return;

    final authState = ref.read(authProvider);
    final currentUser = authState.user;
    if (currentUser == null) return;
    
    // Do not check admin account if current user is admin. Admin side should remain usable.
    if (currentUser.role == UserRole.admin) return;

    try {
      final userResponse = await SupabaseService.client
          .from('users')
          .select('account_status, suspension_reason, delete_reason, deleted_at')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (userResponse == null) return;

      final status = userResponse['account_status']?.toString().toLowerCase() ?? 'active';
      final isDeleted = status == 'deleted' || userResponse['deleted_at'] != null;

      if (status == 'suspended' || isDeleted) {
        if (!mounted) return;
        setState(() {
          _accountStatusDialogShowing = true;
        });
        _statusCheckTimer?.cancel();

        final isSusp = status == 'suspended';
        final title = isSusp ? 'Account Suspended' : 'Account Deleted';
        final baseMsg = isSusp
            ? 'Your account has been suspended.'
            : 'Your account has been deleted.';
        final reason = isSusp
            ? (userResponse['suspension_reason']?.toString() ?? 'No reason provided.')
            : (userResponse['delete_reason']?.toString() ?? 'No reason provided.');

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: const Color(0xFF132031),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baseMsg,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reason: $reason',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Close dialog
                    Navigator.of(dialogContext).pop();
                    
                    // Sign out and clear auth state
                    ref.read(authProvider.notifier).logout();
                    
                    // Go to login screen safely
                    context.go('/login');
                  },
                  child: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking account status: $e');
    }
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/user/shop') || loc.startsWith('/user/vendors')) return 1;
    if (loc.startsWith('/user/orders')) return 2;
    if (loc.startsWith('/user/profile')) return 3;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    _checkAccountStatus(); // Check on tapping page
    if (index == _selectedIndex(context)) return;
    HapticFeedback.selectionClick();
    _springController.forward(from: 0.0);

    switch (index) {
      case 0:
        context.go('/user');
        break;
      case 1:
        context.go('/user/shop');
        break;
      case 2:
        context.go('/user/orders');
        break;
      case 3:
        context.go('/user/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AeroDropBottomNavigation(
            selectedIndex: selected,
            onTap: (index) => _onTap(index, context),
            onFabPressed: () {
              _checkAccountStatus(); // Check account status
              HapticFeedback.mediumImpact();
              context.push('/user/cart');
            },
          ),
        ),
      ),
    );
  }
}
