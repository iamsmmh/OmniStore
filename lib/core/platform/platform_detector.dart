/// Runtime detection of the current target's capabilities.
///
/// Isolated in its own file so that a web build can swap it via conditional
/// imports without touching the capability model or its consumers.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:omnistore/core/platform/platform_capabilities.dart';

/// Returns the capability set for the platform the app is running on.
PlatformCapabilities detectPlatformCapabilities() {
  if (kIsWeb) return PlatformCapabilities.web;

  if (Platform.isAndroid) return PlatformCapabilities.android;
  if (Platform.isIOS) return PlatformCapabilities.ios;
  if (Platform.isWindows) {
    return PlatformCapabilities.desktop.withTarget(TargetPlatform2.windows);
  }
  if (Platform.isMacOS) {
    return PlatformCapabilities.desktop.withTarget(TargetPlatform2.macos);
  }
  if (Platform.isLinux) {
    return PlatformCapabilities.desktop.withTarget(TargetPlatform2.linux);
  }

  // Unknown target: assume the most restrictive, browse-only profile.
  return PlatformCapabilities.web;
}
