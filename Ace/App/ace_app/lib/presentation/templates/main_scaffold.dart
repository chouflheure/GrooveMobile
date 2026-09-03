import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../screens/auth/auth_view_model.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  static const _tabs = [
    _TabItem(path: '/courts', icon: Icons.location_on_outlined, activeIcon: Icons.location_on_rounded, label: 'Terrains'),
    _TabItem(path: '/community', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Communauté'),
    _TabItem(path: '/profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil'),
  ];

  static const _managerTab = _TabItem(
    path: '/manager',
    icon: Icons.shield_outlined,
    activeIcon: Icons.shield_rounded,
    label: 'Manager',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isAdmin = ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;
    final tabs = isAdmin ? [..._tabs, _managerTab] : _tabs;

    int currentIndex = tabs.indexWhere((t) => location.startsWith(t.path));
    if (currentIndex == -1) currentIndex = 0;

    // extendBody: true makes the body extend behind the bottom nav.
    // The MediaQuery override propagates the nav bar height as bottom padding
    // so SafeArea in every nested screen accounts for it automatically.
    final mq = MediaQuery.of(context);
    final navBarHeight = AppSpacing.bottomNavHeight + mq.padding.bottom;

    return Scaffold(
      extendBody: true,
      body: MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(bottom: navBarHeight),
        ),
        child: child,
      ),
      bottomNavigationBar: _BottomNav(
        tabs: tabs,
        currentIndex: currentIndex,
        onTap: (i) => context.go(tabs[i].path),
      ),
    );
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _BottomNav extends StatelessWidget {
  final List<_TabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.bottomNavHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final isActive = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? tab.activeIcon : tab.icon,
                        color: isActive ? AppColors.primary : AppColors.textTertiary,
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: isActive ? AppColors.primary : AppColors.textTertiary,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (isActive)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
