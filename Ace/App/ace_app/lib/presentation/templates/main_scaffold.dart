import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../molecules/molecules.dart';
import '../screens/auth/auth_view_model.dart';
import '../screens/community/community_view_model.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  static const _tabs = [
    _TabItem(
      path: '/courts',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _TabItem(
      path: '/community',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Communauté',
    ),
    _TabItem(
      path: '/profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
  ];

  static const _managerTab = _TabItem(
    path: '/manager',
    icon: Icons.admin_panel_settings_outlined,
    activeIcon: Icons.admin_panel_settings_rounded,
    label: 'Manager',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final hasNewMessage = ref.watch(hasNewMessageProvider);
    final hasNewAnnouncement = ref.watch(hasNewAnnouncementProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;

    // Web: a persistent top bar (logo + Message/Broadcast/Profil/Admin)
    // replaces the bottom tab bar entirely — see `_WebTopBar`. Mobile and
    // tablet keep today's bottom nav, untouched below.
    if (kIsWeb) {
      final communityTab = ref.watch(
        communityViewModelProvider.select((s) => s.activeTab),
      );
      return Scaffold(
        appBar: _WebTopBar(
          location: location,
          communityTab: communityTab,
          isAdmin: isAdmin,
          hasNewMessage: hasNewMessage,
          hasNewAnnouncement: hasNewAnnouncement,
        ),
        body: child,
      );
    }

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
        data: mq.copyWith(padding: mq.padding.copyWith(bottom: navBarHeight)),
        child: child,
      ),
      bottomNavigationBar: _BottomNav(
        tabs: tabs,
        currentIndex: currentIndex,
        badgeIndex: (hasNewMessage || hasNewAnnouncement)
            ? tabs.indexWhere((t) => t.path == '/community')
            : -1,
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
  final int badgeIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.badgeIndex,
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textTertiary,
                            size: 24,
                          ),
                          if (i == badgeIndex)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
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

/// Web-only persistent top bar — the brand mark (tap to go home) on the
/// left, Message/Broadcast/Profil/Admin on the right. Message and
/// Broadcast both route to `/community` (a single screen with its own
/// internal Messages/Annonces tabs — see `CommunityViewModel`), setting
/// the matching sub-tab on the way there so each button behaves like its
/// own first-class destination.
class _WebTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String location;
  final CommunityTab communityTab;
  final bool isAdmin;
  final bool hasNewMessage;
  final bool hasNewAnnouncement;

  const _WebTopBar({
    required this.location,
    required this.communityTab,
    required this.isAdmin,
    required this.hasNewMessage,
    required this.hasNewAnnouncement,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCommunity = location.startsWith('/community');

    return AppBar(
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: GestureDetector(
        onTap: () => context.go('/courts'),
        child: const AppBrandMark(),
      ),
      actions: [
        const NotificationBellButton(),
        const SizedBox(width: AppSpacing.xs),
        _WebNavButton(
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Message',
          isActive: isCommunity && communityTab == CommunityTab.messages,
          showBadge: hasNewMessage,
          onTap: () {
            ref
                .read(communityViewModelProvider.notifier)
                .setTab(CommunityTab.messages);
            context.go('/community');
          },
        ),
        _WebNavButton(
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
          label: 'Broadcast',
          isActive: isCommunity && communityTab == CommunityTab.announcements,
          showBadge: hasNewAnnouncement,
          onTap: () {
            ref
                .read(communityViewModelProvider.notifier)
                .setTab(CommunityTab.announcements);
            context.go('/community');
          },
        ),
        _WebNavButton(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profil',
          isActive: location.startsWith('/profile'),
          onTap: () => context.go('/profile'),
        ),
        if (isAdmin)
          _WebNavButton(
            icon: Icons.admin_panel_settings_outlined,
            activeIcon: Icons.admin_panel_settings_rounded,
            label: 'Admin',
            isActive: location.startsWith('/manager'),
            onTap: () => context.go('/manager'),
          ),
        const SizedBox(width: AppSpacing.md),
      ],
    );
  }
}

class _WebNavButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool showBadge;
  final VoidCallback onTap;

  const _WebNavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.showBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: color),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(isActive ? activeIcon : icon, size: 20, color: color),
            if (showBadge)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        label: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
