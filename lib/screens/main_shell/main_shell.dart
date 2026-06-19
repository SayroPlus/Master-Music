import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/library/library_screen.dart';
import '../../screens/organize/organize_screen.dart';
import '../../screens/stats/stats_screen.dart';
import '../../screens/player/player_screen.dart';
import '../../screens/player/mini_player.dart';
import '../../widgets/bottom_nav.dart';
import 'package:flutter/services.dart';
import '../../providers/navigation_provider.dart';


/// Main application shell that contains the bottom navigation bar
/// and uses an [IndexedStack] to preserve screen state across tab switches.
class MainShell extends ConsumerStatefulWidget {
  final bool loadedFromCache;

  const MainShell({super.key, this.loadedFromCache = false});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {


  /// The four main screens, kept alive via IndexedStack.
  final List<Widget> _screens = const [
    LibraryScreen(),
    OrganizeScreen(),
    StatsScreen(),
    PlayerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.loadedFromCache) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Find last scanned date logic normally derived from provider, but 
        // library screen renders it natively. Just throwing success message globally.
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF2A2A2A),
            content: Text('Library loaded from cache successfully', style: TextStyle(color: Colors.white)),
          ),
        );
      });
    }
  }

  void _onTabChanged(int index) {
    ref.read(navigationProvider.notifier).setTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider).currentIndex;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: _screens,
            ),
          ),
          // Only show mini player if we are NOT on the Player tab itself
          if (currentIndex != 3)
            MiniPlayer(
              onTap: () => _onTabChanged(3),
            ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: currentIndex,
        onTap: _onTabChanged,
      ),
    );
  }
}
