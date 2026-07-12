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
      backgroundColor: Colors.black,
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index == 0) {
            unawaited(
              ref.read(libraryControllerProvider.notifier).showAllPhotos(),
            );
          }
          ref.read(mainTabIndexProvider.notifier).state = index;
        },
        backgroundColor: Colors.black,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_album_outlined),
            selectedIcon: Icon(Icons.photo_album),
            label: 'Albums',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
