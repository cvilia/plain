/// Android-native style toast (not Material SnackBar).
///
/// Visual spec follows platform Toast:
/// - dark pill `#323232`, white 14sp text
/// - horizontally centered, near the bottom
/// - fade in/out, auto-dismiss, non-interactive
library;

import 'package:flutter/material.dart';
import 'package:plain/core/constants/app_constants.dart';

/// Android toast background (framework `Toast` surface).
const Color _toastBg = Color(0xFF323232);

OverlayEntry? _activeToast;

/// Show an Android-native style toast.
///
/// [bottom] lifts it above tab bar / action rows (0 = default inset).
void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = UiDurations.saveToast,
  double bottom = 100,
}) {
  _showToast(
    context,
    message,
    duration: duration,
    bottom: bottom,
  );
}

/// Toast with a single inline action (e.g. undo).
///
/// Android Toast has no actions; this keeps the same pill and places the
/// action as a high-contrast text button on the right.
void showAppToastWithAction(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
  Duration duration = UiDurations.undoWindow,
  double bottom = 100,
}) {
  _showToast(
    context,
    message,
    duration: duration,
    bottom: bottom,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

void _showToast(
  BuildContext context,
  String message, {
  required Duration duration,
  required double bottom,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  // Replace any visible toast (platform Toast queue shows one at a time).
  _activeToast?.remove();
  _activeToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ToastView(
      message: message,
      duration: duration,
      bottom: bottom,
      actionLabel: actionLabel,
      onAction: onAction == null
          ? null
          : () {
              onAction();
              entry.remove();
              if (identical(_activeToast, entry)) _activeToast = null;
            },
      onDismissed: () {
        entry.remove();
        if (identical(_activeToast, entry)) _activeToast = null;
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.duration,
    required this.bottom,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Duration duration;
  final double bottom;
  final VoidCallback onDismissed;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _controller.forward();
    Future<void>.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = widget.bottom > 0 ? widget.bottom : (mq.padding.bottom + 24);
    return IgnorePointer(
      ignoring: widget.onAction == null,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            child: _ToastPill(
              message: widget.message,
              actionLabel: widget.actionLabel,
              onAction: widget.onAction,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Android 12+ toast: dark rounded pill, 14sp white text, max 80% width.
    return Material(
      color: _toastBg,
      elevation: 0,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: actionLabel == null ? 20 : 8,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF80CBC4),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
