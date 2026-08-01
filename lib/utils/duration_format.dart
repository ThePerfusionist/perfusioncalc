// Elapsed-time formatting for the cardioplegia re-dose clock.
//
// Lives here rather than as a private static inside the screen's State so
// it can be unit tested: it is pure, it has interesting boundaries (59/60 s,
// 3599/3600 s), and it feeds both the timer card and the in-app banner -
// they must never disagree about how long ago the last dose was given.

/// "mm:ss" below an hour, "h:mm:ss" from an hour on.
///
/// Minutes and seconds are always two digits so the number does not jump
/// around while the clock runs; the hour is not padded, because "1:05:00"
/// reads better than "01:05:00" at a glance.
String formatElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
