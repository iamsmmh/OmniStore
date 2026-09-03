// Re-export from home page's discover tab
export 'package:omnistore/features/home/presentation/pages/home_page.dart'
    show HomePage;

import 'package:flutter/material.dart';

// Standalone discover page wrapper
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    // In full app, this would be the standalone Discover feature
    // For now, the discover functionality is embedded in the home tab
    return const Scaffold(
      body: Center(child: Text('Discover')),
    );
  }
}
