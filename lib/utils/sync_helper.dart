import 'package:flutter/material.dart';
import '../widgets/pulse_loader.dart';
import '../core/theme.dart';

/// Runs [task] while showing a non-blocking semi-transparent sync overlay.
/// Avoids the full-black modal dialog that appeared after granting permissions.
Future<T> runWithSyncOverlay<T>(
  BuildContext context,
  Future<T> Function() task, {
  String message = 'Syncing your health data...',
}) async {
  if (!context.mounted) return task();

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => Material(
      color: Colors.black.withOpacity(0.45),
      child: PulseLoadingIndicator(message: message),
    ),
  );

  overlay.insert(entry);

  try {
    return await task();
  } finally {
    entry.remove();
  }
}

/// Lightweight inline sync banner used inside screens.
class SyncStatusBanner extends StatelessWidget {
  final String message;

  const SyncStatusBanner({super.key, this.message = 'Syncing health data...'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PulseTheme.surface.withOpacity(0.92),
        border: Border.all(color: PulseTheme.accent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: PulseTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: PulseTheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
