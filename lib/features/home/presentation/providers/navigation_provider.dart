import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the current navigation tab index
final currentIndexProvider = StateProvider<int>((ref) => 0);
