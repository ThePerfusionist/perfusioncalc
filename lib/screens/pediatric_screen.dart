import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/transfusion_settings.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

class PediatricScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const PediatricScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<PediatricScreen> createState() => _PediatricScreenState();
}

class _PediatricScreenState extends State<PediatricScreen> {
  PatientData get patientData => widget.patientData;

  void onChanged() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  TransfusionSettings get tx => TransfusionSettings.instance;

  @override
  void initState() {
    super.initState();
    // The setting can also be changed from elsewhere later on; listening
    // keeps the field and the result in step either way.
    tx.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    tx.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 10),
          _sectionTitle(t('ped_title_tube')),
          const SizedBox(height: 8),
          _fancyTable(
            headers: [t('ped_col_weight'), t('ped_col_art_line'), t('ped_col_ven_line')],
            rows: const [
              ['0 \u2013 3', '3/16"', '3/16"'], ['3 \u2013 5', '3/16"', '1/4"'],
              ['6 \u2013 10', '1/4"', '1/4"'],  ['11 \u2013 30', '1/4"', '3/8"'],
              ['31 \u2013 50', '3/8"', '3/8"'], ['> 50', '3/8"', '1/2"'],
            ],
            flexes: [3, 2, 2],
          ),
          const SizedBox(height: 16),
          _sectionTitle(t('ped_title_perfusion')),
          const SizedBox(height: 8),
          _fancyTable(
            headers: [t('ped_col_weight'), t('ped_col_flow')],
            rows: const [
              ['0 \u2013 3', '120 \u2013 200'], ['3 \u2013 10', '125 \u2013 175'],
              ['10 \u2013 30', '120 \u2013 150'], ['30 \u2013 50', '75 \u2013 100'],
              ['> 55', '65'],
            ],
            flexes: [2, 3],
          ),
          const SizedBox(height: 16),
          ImageSectionCard(title: t('ped_title_va'), assetPath: 'assets/finck_va.jpg'),
          const SizedBox(height: 8),
          ImageSectionCard(title: t('ped_title_vv'), assetPath: 'assets/finck_vv.jpg'),
          const SizedBox(height: 16),
          _sectionTitle(t('ped_title_bv')),
          const SizedBox(height: 8),
          InputCard(label: t('bsa_body_weight'), unit: 'kg', value: patientData.pediatricWeight,
              range: Ranges.pediatricWeight,
              onChanged: (v) { patientData.pediatricWeight = v; onChanged(); }),
          _bvResult(t('ped_bv_premature'), 100),
          _bvResult(t('ped_bv_babies'),     85),
          _bvResult(t('ped_bv_children'),   75),
          _bvResult(t('ped_bv_male'),       70),
          _bvResult(t('ped_bv_female'),     65),
          const SizedBox(height: 16),
          _sectionTitle(t('ped_title_transfusion')),
          const SizedBox(height: 8),
          InputCard(label: t('ped_desired_hb'), unit: 'g/dl', value: patientData.desiredHbIncrease,
              range: Ranges.desiredHbIncrease,
              onChanged: (v) { patientData.desiredHbIncrease = v; onChanged(); }),

          // ── Persisted institutional setting ────────────────────────────
          // Davies' formula divides by this, so the result scales directly
          // with it: 50 % versus 70 % is a 40 % difference in volume. It
          // used to be a hard-coded 0.55 that nobody could see or check.
          const SizedBox(height: 12),
          _sectionTitle(t('ped_hct_ek_section')),
          const SizedBox(height: 8),
          InputCard(
            label: t('ped_hct_in_ek'),
            unit: '%',
            value: tx.rbcUnitHematocritPercent,
            range: Ranges.rbcUnitHematocrit,
            step: 1,
            onChanged: (v) {
              if (v != null) tx.setRbcUnitHematocritPercent(v);
              onChanged();
            },
          ),
          _hintRow(Icons.save_outlined, t('ped_hct_ek_hint')),
          // Only while untouched: a value the user has confirmed once needs
          // no further nagging.
          if (tx.isDefault) _hintRow(Icons.info_outline, t('ped_hct_ek_default')),
          const SizedBox(height: 8),

          ResultCard(label: t('ped_transfusion_vol'), unit: 'ml',
              value: patientData.transfusionVolume(tx.rbcUnitHematocritPercent),
              rangeHint: '${t('ped_hct_in_ek')}: '
                  '${tx.rbcUnitHematocritPercent.toStringAsFixed(0)} %',
              decimals: 0,
              missingInputs: [
                if (patientData.pediatricWeight == null) t('bsa_body_weight'),
                if (patientData.desiredHbIncrease == null) t('ped_desired_hb'),
              ]),
          const SizedBox(height: 8),
          PdfExportButton(
            filename: 'pediatric',
            tabTitleKey: 'tab_pediatric',
            buildSections: () => buildPediatricPdfSections(patientData),
          ),
          SourceButton(refs: [
            AppSources.oldeen2020,
            AppSources.ramakrishnan2023,
            AppSources.finck,
            AppSources.linderkamp1977,
            AppSources.howie,
            AppSources.davies,
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  /// Small explanatory line under an input - same visual weight as the
  /// note rows on the cardioplegia tab.
  Widget _hintRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 6, bottom: 2, right: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: kTextMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(color: kTextMuted, fontSize: 11.5, height: 1.35)),
          ),
        ]),
      );

  Widget _sectionTitle(String title) =>
      Text(title, style: const TextStyle(color: kGold, fontSize: 15, fontWeight: FontWeight.bold));

  Widget _bvResult(String label, double factor) {
    final w = patientData.pediatricWeight ?? 0;
    return ResultCard(
      label: '$label (${factor.toInt()} ml/kg)',
      unit: 'ml',
      value: w * factor,
      decimals: 0,
      missingInputs: patientData.pediatricWeight == null ? [t('bsa_body_weight')] : const [],
    );
  }

  Widget _fancyTable({required List<String> headers, required List<List<String>> rows, required List<int> flexes}) {
    return Container(
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kDivider)),
      child: Column(children: [
        Container(
          decoration:  BoxDecoration(color: kTableHeaderBg, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: headers.asMap().entries.map((e) =>
            Expanded(flex: flexes[e.key],
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Text(e.value, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13))))).toList()),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key; final r = e.value; final isLast = i == rows.length - 1;
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? kRowStripeA : kRowStripeB,
              borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : BorderRadius.zero,
              border: isLast ? null :  Border(bottom: BorderSide(color: kSurfaceWash)),
            ),
            child: Row(children: r.asMap().entries.map((ce) =>
              Expanded(flex: flexes[ce.key],
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(ce.value, style: TextStyle(
                    color: ce.key == 0 ? kGold : kText,
                    fontSize: 14,
                    fontWeight: ce.key == 0 ? FontWeight.w600 : FontWeight.normal))))).toList()),
          );
        }),
      ]),
    );
  }
}

// ── PDF sections (extracted, for the single-tab export and the combined report) ─
List<PdfSection> buildPediatricPdfSections(PatientData pd) {
  // Read here rather than passed in, like the del Nido ratio in the
  // cardioplegia export. The hematocrit MUST appear in the PDF: without it
  // the transfusion volume is not reproducible, and a reader six months
  // later cannot tell which product it was calculated for.
  final hctPercent = TransfusionSettings.instance.rbcUnitHematocritPercent;
  return [
    PdfSection(title: t('pdf_inputs'), rows: [
      PdfRow.numeric(label: t('bsa_body_weight'), value: pd.pediatricWeight,   unit: 'kg'),
      PdfRow.numeric(label: t('ped_desired_hb'),  value: pd.desiredHbIncrease, unit: 'g/dl', decimals: 1),
      // resultIf, NICHT der nackte Wert (Eigenbefund v0.4.12): Der
      // EK-Haematokrit kommt aus einer Einstellung und ist IMMER gesetzt -
      // hier ungefiltert eingetragen, enthielt der Pädiatrie-Tab damit
      // selbst dann eine Zahl, wenn niemand ihn angefasst hatte. Der
      // Gesamtbericht filtert ueber "enthaelt mindestens einen Wert, der
      // nicht — ist" und haette den Tab folglich JEDEM Bericht beigelegt.
      //
      // Dieselbe Falle, die natriumSollTouched und bsaCardiacIndexTouched
      // an anderer Stelle bereits entschaerfen: ein Vorbelegungswert ist
      // keine Eingabe.
      PdfRow.numeric(label: t('ped_hct_in_ek'),
          value: resultIf([pd.pediatricWeight, pd.desiredHbIncrease], hctPercent),
          unit: '%', decimals: 0),
    ]),
    PdfSection(title: t('pdf_results'), rows: [
      PdfRow.numeric(label: t('ped_transfusion_vol'),
          value: pd.transfusionVolume(hctPercent), unit: 'ml', decimals: 0,
          note: '${t('ped_hct_in_ek')}: ${hctPercent.toStringAsFixed(0)} %'),
    ]),
  ];
}
