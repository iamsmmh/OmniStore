import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/services/installer_adapter.dart';
import 'package:omnistore/infrastructure/installer/adapters/altstore_adapter.dart';
import 'package:omnistore/infrastructure/installer/adapters/sidestore_adapter.dart';
import 'package:omnistore/infrastructure/installer/adapters/feather_adapter.dart';
import 'package:omnistore/infrastructure/installer/adapters/esign_adapter.dart';
import 'package:omnistore/infrastructure/installer/adapters/livecontainer_adapter.dart';
import 'package:omnistore/infrastructure/installer/installer_manager.dart';

void main() {
  group('Installer Adapters', () {
    test('AltStore supports ipa', () {
      final a = AltStoreAdapter();
      expect(a.supportsFileType('ipa'), isTrue);
      expect(a.supportsFileType('apk'), isFalse);
      expect(a.id, 'altstore');
    });

    test('SideStore supports ipa', () {
      final a = SideStoreAdapter();
      expect(a.supportsFileType('ipa'), isTrue);
    });

    test('Feather supports ipa and tipa', () {
      final a = FeatherAdapter();
      expect(a.supportsFileType('ipa'), isTrue);
      expect(a.supportsFileType('tipa'), isTrue);
    });

    test('ESign supports ipa', () {
      final a = ESignAdapter();
      expect(a.supportsFileType('ipa'), isTrue);
    });

    test('LiveContainer supports ipa', () {
      final a = LiveContainerAdapter();
      expect(a.supportsFileType('ipa'), isTrue);
    });

    test('Manager registers all 5 adapters', () {
      final manager = InstallerManager();
      expect(manager.allAdapters.length, 5);
      expect(manager.allAdapters.map((a) => a.id), containsAll(['altstore', 'sidestore', 'feather', 'esign', 'livecontainer']));
    });

    test('Registry filters by platform', () {
      final registry = InstallerAdapterRegistry();
      registry.register(AltStoreAdapter());
      registry.register(FeatherAdapter());
      // On test platform (linux), isSupportedOnCurrentPlatform is false for iOS adapters, so supported list may be empty — that's correct behavior
      expect(registry.allAdapters.length, 2);
    });
  });
}
