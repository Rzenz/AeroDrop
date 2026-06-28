import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'widgets/aerodrop_bottom_navigation.dart';

class UserShell extends StatefulWidget {
  final Widget child;
  const UserShell({super.key, required this.child});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> with TickerProviderStateMixin {
  late AnimationController _springController;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/user/track')) return 1;
    if (loc.startsWith('/user/history')) return 2;
    if (loc.startsWith('/user/profile')) return 3;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    if (index == _selectedIndex(context)) return;
    HapticFeedback.selectionClick();
    _springController.forward(from: 0.0);

    switch (index) {
      case 0:
        context.go('/user');
        break;
      case 1:
        context.go('/user/track');
        break;
      case 2:
        context.go('/user/history');
        break;
      case 3:
        context.go('/user/profile');
        break;
    }
  }

  // Tab building is now delegated to AeroDropBottomNavigation.

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
              HapticFeedback.mediumImpact();
              context.push('/user/request');
            },
          ),
        ),
      ),
    );
  }
}
