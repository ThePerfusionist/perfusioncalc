// Tests for the cardioplegia tab layout and its PDF sections
// ==========================================================
// v0.4.38 changed three things on this tab, and each has a test here:
//
//  1. The grey protocol info box moved from the top of every protocol to
//     directly above "Export as PDF".
//  2. On Calafiore, the Perfusor syringe moved below the results
//     ("Cardioplegia volume").
//  3. The syringe is now a persisted setting. That is the one with a
//     non-obvious failure mode: a setting is present in every session, so if
//     it counted as "input" the tab would be attached to every combined
//     report forever (C-1, PROJECT_STATE § 3). The PDF tests pin that down.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfusion_calc/i18n/app_strings.dart';
import 'package:perfusion_calc/models/cardioplegia_settings.dart';
import 'package:perfusion_calc/models/patient_data.dart';
import 'package:perfusion_calc/screens/cardioplegia_screen.dart';
import 'package:perfusion_calc/utils/pdf_export.dart';
import 'package:perfusion_calc/widgets/common.dart';

/// Same predicate as MainScreen._exportCombinedReport().
bool countsAsFilled(List<PdfSection> sections) =>
    sections.any((s) => s.rows.any((r) => r.value != '—'));

String? valueOf(List<PdfSection> sections, String label) {
  for (final section in sections) {
    for (final row in section.rows) {
      if (row.label == label) return row.value;
    }
  }
  return null;
}

Future<void> fillInstitutionalSyringe(CardioplegiaSettings cfg) async {
  await cfg.setCalafioreKclVolume(40);
  await cfg.setCalafioreKclConc(2.0);
  await cfg.setCalafioreMgVolume(10);
  await cfg.setCalafioreMgConc(2.0);
}

Future<void> clearSyringe(CardioplegiaSettings cfg) async {
  await cfg.setCalafioreKclVolume(null);
  await cfg.setCalafioreKclConc(null);
  await cfg.setCalafioreMgVolume(null);
  await cfg.setCalafioreMgConc(null);
  await cfg.setCalafioreKclInPercent(false);
  await cfg.setCalafioreMgInPercent(false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cfg = CardioplegiaSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearSyringe(cfg);
  });

  group('PDF sections with a persisted syringe', () {
    test('A stored syringe alone does not make the tab "filled"', () async {
      // The regression this guards against: the syringe survives restarts,
      // so a brand-new case already "has" it. If that were enough to count
      // as input, the cardioplegia tab would be in every combined report.
      await fillInstitutionalSyringe(cfg);
      final sections = buildCardioplegiaPdfSections(PatientData());
      expect(countsAsFilled(sections), isFalse);
      final labels = sections.expand((s) => s.rows).map((r) => r.label);
      expect(labels.where((l) => l.contains('Calafiore')), isEmpty);
    });

    test('With per-case input the syringe rows and the rate appear', () async {
      await fillInstitutionalSyringe(cfg);
      final pd = PatientData()
        ..cardioplegiaCalafioreDoseNumber = 1
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      final sections = buildCardioplegiaPdfSections(pd);
      expect(countsAsFilled(sections), isTrue);
      // Same numbers as the unit tests: 1.6 mmol/ml K+, dose 1 -> 114.0 ml/h.
      expect(valueOf(sections, '${t('cardio_perfusor_rate')} (Calafiore)'), '114.0');
      expect(valueOf(sections, '${t('cardio_mg_delivery')} (Calafiore)'), '45.60');
      expect(valueOf(sections, '${t('cardio_syringe_k_conc')} (Calafiore)'), '1.60');
      expect(valueOf(sections, '${t('cardio_kcl_volume')} (Calafiore)'), isNot('\u2014'));
      // 50 ml / 114 ml/h = 26.3 min.
      expect(valueOf(sections, '${t('cardio_syringe_runtime')} (Calafiore)'), '26');
    });

    test('No supplementation needed -> runtime row prints "\u2014", not "0"', () async {
      await fillInstitutionalSyringe(cfg);
      final pd = PatientData()
        ..cardioplegiaCalafioreDoseNumber = 2
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 12.0;
      final sections = buildCardioplegiaPdfSections(pd);
      expect(valueOf(sections, '${t('cardio_syringe_runtime')} (Calafiore)'), '\u2014');
    });

    test('Per-case input without a syringe still prints "—" for the rate', () {
      final pd = PatientData()
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      final sections = buildCardioplegiaPdfSections(pd);
      expect(valueOf(sections, '${t('cardio_perfusor_rate')} (Calafiore)'), '—');
    });
  });

  group('Layout', () {
    Future<void> pumpScreen(WidgetTester tester, {PatientData? pd}) async {
      // Tall surface so the whole column is laid out without scrolling.
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CardioplegiaScreen(patientData: pd ?? PatientData(), onChanged: () {}),
        ),
      ));
      await tester.pump();
    }

    double top(WidgetTester tester, String text) =>
        tester.getTopLeft(find.text(text).first).dy;

    testWidgets('Calafiore: flow -> results -> syringe -> info box -> PDF',
        (tester) async {
      await pumpScreen(tester);
      final dose = top(tester, t('cardio_dose_number'));
      final flow = top(tester, t('cardio_flow_section'));
      final result = top(tester, t('cardio_section_result'));
      final syringe = top(tester, t('cardio_syringe_section'));
      final info = top(tester, t('cardio_calafiore_principle'));
      final pdf = top(tester, t('pdf_export_button'));
      expect(dose, lessThan(flow));
      expect(flow, lessThan(result));
      expect(result, lessThan(syringe),
          reason: 'syringe sits below "Cardioplegia volume"');
      expect(syringe, lessThan(info));
      expect(info, lessThan(pdf),
          reason: 'grey info box sits directly above the PDF export');
    });

    testWidgets('Every visible protocol shows its info box above the PDF button',
        (tester) async {
      await pumpScreen(tester);
      final firstLine = {
        'Bretschneider': t('cardio_bret_principle'),
        'del Nido': t('cardio_ratio_delnido'),
        'Calafiore': t('cardio_calafiore_principle'),
      };
      for (final entry in firstLine.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pump();
        final info = top(tester, entry.value);
        final pdf = top(tester, t('pdf_export_button'));
        final timer = top(tester, t('cardio_timer_section'));
        expect(timer, lessThan(info), reason: '${entry.key}: timer first');
        expect(info, lessThan(pdf), reason: '${entry.key}: info above PDF');
        expect(find.text(entry.value), findsOneWidget,
            reason: '${entry.key}: info box rendered once');
      }
    });

    testWidgets('Runtime card: shows the minutes, hidden when no K+ is needed',
        (tester) async {
      await fillInstitutionalSyringe(cfg);
      final pd = PatientData()
        ..cardioplegiaCalafioreDoseNumber = 1
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      await pumpScreen(tester, pd: pd);
      final card = find.ancestor(
          of: find.text(t('cardio_syringe_runtime')),
          matching: find.byType(ResultCard));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('26')), findsOneWidget);
      // Sits in the results block, above the syringe section.
      expect(top(tester, t('cardio_syringe_runtime')),
          lessThan(top(tester, t('cardio_syringe_section'))));

      // Serum K+ above the dose-1 target of 20: rate 0, so no runtime card -
      // "0 min" would claim the syringe is empty right away.
      pd.cardioplegiaCalafioreSerumK = 25;
      await pumpScreen(tester, pd: pd);
      expect(find.text(t('cardio_syringe_runtime')), findsNothing);
      expect(find.text(t('cardio_no_dose_needed')), findsOneWidget);
    });

    testWidgets('Runtime card with incomplete inputs shows "\u2014", not "0"',
        (tester) async {
      await pumpScreen(tester);
      final card = find.ancestor(
          of: find.text(t('cardio_syringe_runtime')),
          matching: find.byType(ResultCard));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('\u2014')), findsOneWidget);
    });

    testWidgets('Syringe entered in the UI lands in the persisted setting',
        (tester) async {
      await pumpScreen(tester);
      final field = find.descendant(
        of: find.ancestor(
            of: find.text(t('cardio_kcl_volume')),
            matching: find.byType(InputCard)),
        matching: find.byType(TextField),
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, '40');
      await tester.pump();
      expect(cfg.calafioreSyringe.kclVolume, 40);
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble('cpl_calafiore_kcl_volume'), 40);
    });
  });

  test('German label for the dose selector is just "Gabe"', () {
    expect(Strings.of('cardio_dose_number', AppLocale.de), 'Gabe');
  });
}
