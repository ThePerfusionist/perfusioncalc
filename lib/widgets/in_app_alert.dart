// In-app alert banner for the cardioplegia re-dose reminder
// ===========================================================
//
// WHY THIS EXISTS
// System notifications can be suppressed outside the app's control: Windows
// notification settings, "Do not disturb", or a browser running full screen
// all swallow them silently, with no error reported back. That is exactly
// what happened during testing - the browser accepted the notification, the
// OS never showed it.
//
// This banner is drawn by the app itself, so it appears regardless of those
// settings. It complements the system notification rather than replacing it:
// the system one reaches the user when the app is not in front, this one
// guarantees the alert is seen when it is.
//
// Deliberately an OverlayEntry rather than a dialog: a modal dialog would
// block the calculators underneath, and an alert must never stop someone
// mid-calculation during a case.

import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/app_strings.dart';
import 'common.dart';

class InAppAlert {
  static OverlayEntry? _entry;
  static Timer? _autoDismiss;

  /// Shows the banner over the current screen.
  ///
  /// [elapsedText] carries the already formatted elapsed time so this widget
  /// stays free of any timing logic.
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String? elapsedText,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // Replace an existing banner instead of stacking several of them.
    dismiss();

    final entry = OverlayEntry(
      builder: (ctx) => _AlertBanner(
        title: title,
        message: message,
        elapsedText: elapsedText,
        onDismiss: dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    // Auto-dismiss so a missed banner cannot cover the UI indefinitely.
    // Generous, because the whole point is that it gets noticed.
    _autoDismiss = Timer(const Duration(seconds: 30), dismiss);
  }

  static void dismiss() {
    _autoDismiss?.cancel();
    _autoDismiss = null;
    _entry?.remove();
    _entry = null;
  }
}

class _AlertBanner extends StatefulWidget {
  final String title;
  final String message;
  final String? elapsedText;
  final VoidCallback onDismiss;

  const _AlertBanner({
    required this.title,
    required this.message,
    required this.elapsedText,
    required this.onDismiss,
  });

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 260),
    vsync: this,
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Cap the width so the banner does not stretch across a wide desktop
    // window; on phones it simply fills the available space.
    final width = media.size.width < 520 ? media.size.width - 16 : 480.0;

    return Positioned(
      top: media.padding.top + 8,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGold, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.notifications_active, color: kGold, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(widget.title,
                              style: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        if (widget.elapsedText != null)
                          Text(widget.elapsedText!,
                              style: TextStyle(color: kGold, fontSize: 15, fontWeight: FontWeight.w500)),
                      ]),
                      const SizedBox(height: 2),
                      Text(widget.message,
                          style: TextStyle(color: kTextSecondary, fontSize: 12.5)),
                    ]),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: t('cardio_alarm_dismiss'),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onDismiss,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, color: kTextMuted, size: 18),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
