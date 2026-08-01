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
  /// [titleKey] and [messageKey] are i18n KEYS, not finished strings: the
  /// banner stands for 30 seconds, and a language switch while it is up
  /// used to leave the title and body frozen in the old language while the
  /// close button's semantics label - resolved inside build() - followed
  /// along. Resolving both in build() keeps the whole banner consistent.
  ///
  /// [elapsedText] stays a finished string; it is a formatted duration and
  /// carries no language.
  static void show(
    BuildContext context, {
    required String titleKey,
    required String messageKey,
    String? elapsedText,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // Replace an existing banner instead of stacking several of them.
    dismiss();

    final entry = OverlayEntry(
      builder: (ctx) => _AlertBanner(
        titleKey: titleKey,
        messageKey: messageKey,
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
  final String titleKey;
  final String messageKey;
  final String? elapsedText;
  final VoidCallback onDismiss;

  const _AlertBanner({
    required this.titleKey,
    required this.messageKey,
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

  /// Stable across rebuilds because it lives in the State. Deriving the key
  /// from the widget instead would hand Dismissible a new key on every
  /// rebuild and reset its state.
  final Key _dismissKey = UniqueKey();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// One flat sentence for the screen reader: prefix, title, body and, when
  /// present, the elapsed time. Built as a helper rather than inline so the
  /// widget tree stays readable.
  String _semanticsLabel(String title, String message) {
    final buffer = StringBuffer()
      ..write(t('a11y_alert_banner'))
      ..write(': ')
      ..write(title)
      ..write('. ')
      ..write(message);
    final elapsed = widget.elapsedText;
    if (elapsed != null) buffer.write('. $elapsed');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Resolved here, not at the call site - see InAppAlert.show().
    final title = t(widget.titleKey);
    final message = t(widget.messageKey);
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
              // Dismissible provides the swipe-away gesture in both
              // directions with the usual follow-the-finger animation.
              child: Dismissible(
                key: _dismissKey,
                direction: DismissDirection.horizontal,
                onDismissed: (_) => widget.onDismiss(),
                child: GestureDetector(
                  // Tapping anywhere dismisses it as well - hunting for a
                  // small close icon is the wrong interaction during a case.
                  // The icon stays as an explicit affordance.
                  onTap: widget.onDismiss,
                  // Opaque so taps on the padding register too, not only
                  // those landing on the text or icons.
                  behavior: HitTestBehavior.opaque,
                  // liveRegion: this banner appears WITHOUT any user action,
                  // which is exactly the case screen readers need announced.
                  // Without it a TalkBack/VoiceOver user simply never learns
                  // the re-dose reminder fired - the only semantics label on
                  // the banner sat on the close icon.
                  child: Semantics(
                    liveRegion: true,
                    label: _semanticsLabel(title, message),
                    child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 16,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notifications_active, color: kGold, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(title,
                                      style: TextStyle(
                                          color: kText,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (widget.elapsedText != null)
                                  Text(widget.elapsedText!,
                                      style: TextStyle(
                                          color: kGold,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500)),
                              ]),
                              const SizedBox(height: 2),
                              Text(message,
                                  style: TextStyle(
                                      color: kTextSecondary, fontSize: 12.5)),
                            ],
                          ),
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
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
