import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'library_provider.dart';

class NavigationState {
  final int currentIndex;
  
  const NavigationState({
    this.currentIndex = 0,
  });

  NavigationState copyWith({
    int? currentIndex,
  }) {
    return NavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  final Ref ref;

  NavigationNotifier(this.ref) : super(const NavigationState());

  void setTab(int index) {
    state = state.copyWith(currentIndex: index);
  }

  /// Navigates to the library and applies a specific filter.
  void goToLibraryWithFilter(FilterType filter) {
    state = state.copyWith(currentIndex: 0); // 0 is Library
    ref.read(libraryProvider.notifier).setFilter(filter);
  }
}

final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier(ref);
});
