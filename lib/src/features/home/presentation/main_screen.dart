import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/presentation/albums_screen.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/library_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../vault/presentation/vault_pin_screen.dart';

final mainTabIndexProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainTabIndexProvider);

    // Keep pages alive so users don't lose context when switching tabs.
    const pages = [
      LibraryScreen(),
      AlbumsScreen(),
      VaultPinScreen(mode: VaultPinMode.unlock),
      SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.outline)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            if (index == 0) {
              unawaited(
                ref.read(libraryControllerProvider.notifier).showAllPhotos(),
              );
            }
            ref.read(mainTabIndexProvider.notifier).state = index;
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.photo_album_outlined),
              selectedIcon: Icon(Icons.photo_album_rounded),
              label: 'Albums',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_outline_rounded),
              selectedIcon: Icon(Icons.lock_rounded),
              label: 'Vault',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
