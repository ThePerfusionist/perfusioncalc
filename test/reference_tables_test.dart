// Tests for the reference tables reworked in v0.4.40
// ===================================================
// 1. The Finck 2025 cannula tables. They were screenshots of a spreadsheet
//    and are now transcribed data (models/finck_cannula_tables.dart). The
//    values themselves can only be checked against the images, which stay in
//    assets/ for that reason. What a test CAN pin down is what a
//    transcription slip would most likely break: row and column counts, the
//    shared weight bands, the kind of entry each column holds, and that
//    cannula sizes never shrink as the weight goes up — a property of the
//    original that a swapped or mistyped number would violate.
// 2. FrozenColumnTable. The frozen column and the scrolling part are two
//    separate layouts whose rows must line up.
// 3. The flow/drainage table on the tube tab. In the maintainer's screenshot
//    "Schlauch" was split into "Schlauc" + "h" at a larger text size.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfusion_calc/i18n/app_strings.dart';
import 'package:perfusion_calc/models/finck_cannula_tables.dart';
import 'package:perfusion_calc/models/patient_data.dart';
import 'package:perfusion_calc/screens/pediatric_screen.dart';
import 'package:perfusion_calc/screens/tube_volume_screen.dart';
import 'package:perfusion_calc/widgets/frozen_column_table.dart';

const _dash = '–';

/// Leading French size of a cell ("19 Art\nBioMedicus" -> 19,
/// "29/37\nEdwards" -> 29), null for an empty route.
int? _size(String cell) {
  final m = RegExp(r'^\d+').firstMatch(cell);
  return m == null ? null : int.parse(m.group(0)!);
}

List<String> _column(List<List<String>> rows, int c) => [for (final r in rows) r[c]];

Future<void> _pump(WidgetTester tester, Widget child,
    {double width = 393, double height = 6000, double textScale = 1.0}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height), textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: child),
    ),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleNotifier.instance.setLocale(AppLocale.en);
  });

  group('Finck 2025 data', () {
    test('One row per weight band, in the same order in both tables', () {
      expect(kFinckWeightBands, hasLength(24));
      expect(_column(kFinckVaRows, 0), kFinckWeightBands);
      expect(_column(kFinckVvRows, 0), kFinckWeightBands);
    });

    test('V-A rows have 8 cells, V-V rows 6, full-flow rows 2', () {
      for (final r in kFinckVaRows) {
        expect(r, hasLength(8), reason: 'V-A ${r[0]}');
      }
      for (final r in kFinckVvRows) {
        expect(r, hasLength(6), reason: 'V-V ${r[0]}');
      }
      expect(kFinckFullFlowRows, hasLength(5));
      for (final r in kFinckFullFlowRows) {
        expect(r, hasLength(2));
      }
    });

    test('No empty cell, at most two lines per cell', () {
      for (final r in [...kFinckVaRows, ...kFinckVvRows]) {
        for (final c in r) {
          expect(c.trim(), isNotEmpty, reason: r[0]);
          expect('\n'.allMatches(c).length, lessThanOrEqualTo(1), reason: c);
        }
      }
    });

    test('The connector column holds tube sizes only', () {
      // Catches a shifted row: any cannula landing here fails the pattern.
      final size = r'(1/4"|3/8"|1/2")';
      final pattern = RegExp('^$size( \\{or\\} $size)?\$');
      for (final c in [..._column(kFinckVaRows, 7), ..._column(kFinckVvRows, 5)]) {
        expect(pattern.hasMatch(c), isTrue, reason: c);
      }
    });

    test('Each column holds the expected kind of cannula', () {
      for (final r in kFinckVaRows) {
        expect(r[1], contains('BioMedicus'), reason: 'neck venous ${r[0]}');
        expect(r[2], anyOf(endsWith('Edwards'), endsWith('Art\nBioMedicus')),
            reason: 'neck arterial ${r[0]}');
        expect(r[5], anyOf(endsWith('DLP'), endsWith('Edwards')), reason: 'chest venous ${r[0]}');
        expect(r[6], endsWith('DLP'), reason: 'chest arterial ${r[0]}');
      }
      // Groin: no femoral cannulation below 10 kg, from 10 kg on always.
      final first10kg = kFinckWeightBands.indexOf('10 – 12');
      expect(first10kg, greaterThan(0));
      for (var i = 0; i < kFinckWeightBands.length; i++) {
        final va = kFinckVaRows[i], vv = kFinckVvRows[i];
        for (final c in [va[3], va[4], vv[2], vv[3]]) {
          expect(c == _dash, i < first10kg, reason: 'groin at ${va[0]}: $c');
        }
      }
      // Avalon: everything but the smallest band.
      expect(kFinckVvRows.first[4], _dash);
      for (final r in kFinckVvRows.skip(1)) {
        expect(r[4], contains('Avalon DL'), reason: r[0]);
      }
    });

    test('Cannula sizes never decrease with weight', () {
      void check(List<List<String>> rows, int c, String label) {
        int? previous;
        for (final r in rows) {
          final s = _size(r[c]);
          if (s == null) continue;
          if (previous != null) {
            expect(s, greaterThanOrEqualTo(previous), reason: '$label at ${r[0]}');
          }
          previous = s;
        }
      }
      for (var c = 1; c <= 6; c++) {
        check(kFinckVaRows, c, 'V-A column $c');
      }
      // V-V column 1 is left out on purpose: at 15 kg it switches from the
      // dual-lumen OriGen (18 Fr) to a separate reinfusion cannula (14 Fr).
      for (var c = 2; c <= 4; c++) {
        check(kFinckVvRows, c, 'V-V column $c');
      }
    });

    test('{or} resolves in both languages', () {
      final withToken = [...kFinckVaRows, ...kFinckVvRows]
          .expand((r) => r)
          .where((c) => c.contains('{or}'))
          .toList();
      expect(withToken, isNotEmpty, reason: 'otherwise this test checks nothing');
      for (final loc in AppLocale.values) {
        final or = Strings.of('ped_or', loc);
        for (final c in withToken) {
          final resolved = finckOr(c, or);
          expect(resolved, isNot(contains('{')));
          expect(resolved, contains(' $or '));
        }
      }
    });
  });

  group('FrozenColumnTable', () {
    final headers = [
      const FrozenTableHeader('Weight'),
      for (var i = 1; i <= 7; i++) FrozenTableHeader('Col $i', caption: 'Site'),
    ];
    final rows = [
      for (var r = 0; r < 6; r++)
        ['w$r', for (var i = 1; i <= 7; i++) i.isOdd ? '$r$i Art\nBioMedicus' : _dash],
    ];

    testWidgets('Frozen and scrolling cells of a row line up', (tester) async {
      await _pump(tester, FrozenColumnTable(headers: headers, rows: rows),
          width: 360, textScale: 1.5);
      expect(tester.takeException(), isNull);
      for (var r = 0; r < rows.length; r++) {
        final frozen = tester.getCenter(find.text('w$r', findRichText: true));
        final cell = tester.getCenter(find.text('${r}1 Art\nBioMedicus', findRichText: true));
        expect(cell.dy, moreOrLessEquals(frozen.dy, epsilon: 0.01), reason: 'row $r');
      }
    });

    testWidgets('Too wide for the screen: scrolls instead of overflowing', (tester) async {
      await _pump(tester, FrozenColumnTable(headers: headers, rows: rows),
          width: 320, textScale: 2.0);
      expect(tester.takeException(), isNull);
      final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('The frozen column is capped at 45 % of the width', (tester) async {
      // A long first header at a huge text size would otherwise push the
      // scrolling part off the screen (RenderFlex overflow).
      await _pump(
          tester,
          FrozenColumnTable(
            headers: [const FrozenTableHeader('Patient weight in kilograms'), ...headers.skip(1)],
            rows: rows,
          ),
          width: 320,
          textScale: 3.0);
      expect(tester.takeException(), isNull);
      final table = tester.getSize(find.byType(FrozenColumnTable)).width;
      final frozen = tester.getSize(find.descendant(
          of: find.byType(FrozenColumnTable), matching: find.byType(IntrinsicWidth))).width;
      expect(frozen, lessThanOrEqualTo(table * 0.45 + 0.01));
    });

    testWidgets('Fits on a wide screen: nothing to scroll', (tester) async {
      await _pump(tester, FrozenColumnTable(headers: headers, rows: rows), width: 2400);
      expect(tester.takeException(), isNull);
      final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scroll.controller!.position.maxScrollExtent, 0);
    });
  });

  group('Pediatric tab', () {
    // Written out rather than generated in a loop, so that the static test
    // count in consistency_check.py matches what `flutter test` reports.
    Future<void> renders(WidgetTester tester, AppLocale loc, double scale) async {
      await LocaleNotifier.instance.setLocale(loc);
      await _pump(tester, PediatricScreen(patientData: PatientData(), onChanged: () {}),
          width: 360, height: 12000, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.byType(FrozenColumnTable), findsNWidgets(2));
      expect(find.text(t('ped_title_full_flow')), findsOneWidget);
      // The {or} token is resolved, not shown raw.
      expect(find.textContaining('{or}', findRichText: true), findsNothing);
      expect(find.text('13 ${t('ped_or')} 15\nOriGen DL', findRichText: true), findsOneWidget);
    }

    testWidgets('Finck tables render without overflow (EN, text ×1.0, 360 dp)',
        (tester) => renders(tester, AppLocale.en, 1.0));
    testWidgets('Finck tables render without overflow (EN, text ×2.0, 360 dp)',
        (tester) => renders(tester, AppLocale.en, 2.0));
    testWidgets('Finck tables render without overflow (DE, text ×1.0, 360 dp)',
        (tester) => renders(tester, AppLocale.de, 1.0));
    testWidgets('Finck tables render without overflow (DE, text ×2.0, 360 dp)',
        (tester) => renders(tester, AppLocale.de, 2.0));
  });

  group('Tube tab: flow / drainage table', () {
    testWidgets('"Schlauch" stays on one line at a larger text size', (tester) async {
      await LocaleNotifier.instance.setLocale(AppLocale.de);
      await _pump(tester, TubeVolumeScreen(patientData: PatientData(), onChanged: () {}),
          width: 393, height: 2000, textScale: 1.3);
      expect(tester.takeException(), isNull);
      final p = tester.renderObject<RenderParagraph>(find.text('Schlauch'));
      final boxes = p.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 'Schlauch'.length));
      final lines = boxes.map((b) => b.top).toSet();
      expect(lines, hasLength(1), reason: 'header broken across lines');
    });
  });
}
