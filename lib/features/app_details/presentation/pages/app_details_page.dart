import 'package:flutter/material.dart';

/// Standalone app details page wrapper
class AppDetailsPage extends StatelessWidget {
  final String appId;

  const AppDetailsPage({super.key, required this.appId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('App Details: $appId')),
    );
  }
}
