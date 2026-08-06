// Bounds for the +/- stepper buttons
// ==================================
// Pulled out of the private State class in common.dart so it can be tested
// (audit R-3) — same pattern as formatElapsed.
//
// Why this deserves its own test: the logic has two exceptions that nobody
// verifies while reading, and both are clinically relevant.
//
// The first version clamped every step hard to [min, max]. That fixed the
// reported problem (decrementing an empty weight field produced -0.1 kg) but
// overrode a design intent that was written down: the header of ranges.dart
// states explicitly that calculations accept values outside the range, "to
// deliberately work through extreme cases in training" — that is what the
// orange warning is for. With a hard clamp an Hb could still be typed as
// 3 g/dl but no longer stepped below 4, and stepping through exactly that is
// what a teaching tool must be able to do.

import '../models/ranges.dart';

/// Bounds a +/- step to what is physically possible — not to what is
/// plausible.
///
/// [fromEmpty] describes the state BEFORE the step: if the field was empty,
/// the calculation starts from 0, and a decrement should then not fall into
/// negative territory but settle on the lower bound.
///
/// Otherwise it only stops at zero, and even that only where negative values
/// make no sense. Ranges with a negative lower bound — base excess, CVP —
/// keep their negative values; clamping those to 0 would be clinically
/// wrong.
double clampStep(double v, Range? range, {required bool fromEmpty}) {
  if (range == null) return v;
  if (fromEmpty && v < range.min) return range.min;
  if (v < 0 && range.min >= 0) return 0;
  return v;
}
