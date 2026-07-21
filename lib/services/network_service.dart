import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkNotifier extends StateNotifier<bool> {
  Timer? _periodicTimer;

  NetworkNotifier() : super(false) {
    checkConnectivity();
    // Periodically check connectivity every 15 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkConnectivity();
    });
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      final isOffline = !isConnected;
      if (state != isOffline) {
        state = isOffline;
        debugPrint('[NetworkService] Connectivity state changed: isOffline=$isOffline');
      }
      return isConnected;
    } catch (_) {
      if (!state) {
        state = true;
        debugPrint('[NetworkService] Connectivity lost: isOffline=true');
      }
      return false;
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}

final isOfflineProvider = StateNotifierProvider<NetworkNotifier, bool>((ref) {
  return NetworkNotifier();
});
