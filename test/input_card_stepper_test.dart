// Widget test for the stepper buttons on InputCard
// ================================================
// The reported defect (v0.4.34): tapping + or - changed the value, and every
// result on the screen followed — but the number inside the text field kept
// showing the old one. It only caught up once the field was tapped, as if
// for manual entry.
//
// Cause: a separate `_editing` flag was set on the field's `onTap` and
// cleared only by `onEditingComplete` or `onTapOutside`. Tapping a stepper
// triggers neither — both buttons sit inside the same InputCard, so the tap
// is not "outside" the field. The flag stayed true, and didUpdateWidget
// skipped the sync it guards.
//
// The flag is gone; focus is now the only signal. The test below on typing
// is what showed that the flag was wrong in the OTHER direction as well:
// `enterText` focuses the field without firing `onTap`, so the flag stayed
// false and the reformatted text overwrote a partial entry. The same thing
// happens on web and desktop when a field is reached with the Tab key.
//
// These are the first widget tests in the project. They exist because the
// defect is invisible to a unit test: the value was always correct, only its
// rendering was not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/ranges.dart';
import 'package:perfusion_calc/widgets/common.dart';

/// Minimal host that behaves like a real screen: it holds the value and
/// rebuilds on change, exactly as the screens do via _recalc().
class _Host extends StatefulWidget {
  final double? initial;
  final Range? range;
  final double step;
  const _Host({this.initial, this.range, this.step = 0.1});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double? value;

  @override
  void initState() {
    super.initState();
    value = widget.initial;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: InputCard(
            label: 'Weight',
            unit: 'kg',
            value: value,
            range: widget.range,
            step: widget.step,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
}

void main() {
  /// The text currently rendered inside the field.
  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  Future<void> tapPlus(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
  }

  Future<void> tapMinus(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
  }

  testWidgets('Plus updates the displayed number', (tester) async {
    await tester.pumpWidget(const _Host(initial: 70, range: null));
    expect(fieldText(tester), '70');
    await tapPlus(tester);
    expect(fieldText(tester), '70.1');
  });

  testWidgets('Minus updates the displayed number', (tester) async {
    await tester.pumpWidget(const _Host(initial: 70));
    await tapMinus(tester);
    expect(fieldText(tester), '69.9');
  });

  testWidgets('Stepping works after the field has been tapped', (tester) async {
    // The exact reported sequence: tap into the field (which sets _editing),
    // then use the stepper. This is what used to freeze the display.
    await tester.pumpWidget(const _Host(initial: 70));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tapPlus(tester);
    expect(fieldText(tester), '70.1',
        reason: 'the field must follow the value even after being focused');
    await tapPlus(tester);
    expect(fieldText(tester), '70.2');
  });

  testWidgets('Several steps in a row accumulate', (tester) async {
    await tester.pumpWidget(const _Host(initial: 5, step: 1));
    for (var i = 0; i < 4; i++) {
      await tapPlus(tester);
    }
    expect(fieldText(tester), '9');
  });

  testWidgets('Stepping from an empty field lands on the lower bound',
      (tester) async {
    await tester.pumpWidget(_Host(initial: null, range: Ranges.weight));
    expect(fieldText(tester), '');
    await tapMinus(tester);
    expect(fieldText(tester), '0.5');
  });

  testWidgets('Typing is not disturbed by the sync', (tester) async {
    // The guard exists for a reason: while typing, writing the reformatted
    // text back would move the cursor and swallow a partial entry. "82."
    // parses as 82, so an unguarded sync would drop the trailing dot the
    // moment it is typed — and with it the chance to type "82.5".
    //
    // enterText focuses the field WITHOUT firing onTap. That is exactly the
    // case in which the old `_editing` flag stayed false and the guard did
    // not engage; on web and desktop the Tab key produces the same state.
    await tester.pumpWidget(const _Host(initial: null));
    await tester.enterText(find.byType(TextField), '8');
    await tester.pump();
    expect(fieldText(tester), '8');
    await tester.enterText(find.byType(TextField), '82.');
    await tester.pump();
    expect(fieldText(tester), '82.',
        reason: 'a partial entry must survive the rebuild');
  });

  testWidgets('Losing focus catches up on what the guard suppressed',
      (tester) async {
    // "82." is displayed while typing but the model holds 82. Once focus
    // goes away the field has to show the canonical form again, otherwise a
    // dangling dot would stay on screen for good.
    await tester.pumpWidget(const _Host(initial: null));
    await tester.enterText(find.byType(TextField), '82.');
    await tester.pump();
    expect(fieldText(tester), '82.');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(fieldText(tester), '82');
  });

  testWidgets('After losing focus the field catches up with the value',
      (tester) async {
    // The counterpart to the guard: once focus is gone it must let go,
    // otherwise a value changed elsewhere would never reach the display.
    await tester.pumpWidget(const _Host(initial: 70));
    await tester.enterText(find.byType(TextField), '80.0');
    await tester.pump();
    expect(fieldText(tester), '80.0', reason: 'still focused, so untouched');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(fieldText(tester), '80',
        reason: 'after losing focus the text is normalised from the value');
  });

  testWidgets('A step after typing continues from the typed value',
      (tester) async {
    await tester.pumpWidget(const _Host(initial: null, step: 1));
    await tester.enterText(find.byType(TextField), '80');
    await tester.pump();
    await tapPlus(tester);
    expect(fieldText(tester), '81');
  });
}
