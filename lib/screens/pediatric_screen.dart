import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
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
          ResultCard(label: t('ped_transfusion_vol'), unit: 'ml', value: patientData.transfusionVolume,
              rangeHint: t('ped_hct_in_ek'), decimals: 0,
              missingInputs: [
                if (patientData.pediatricWeight == null) t('bsa_body_weight'),
                if (patientData.desiredHbIncrease == null) t('ped_desired_hb'),
              ]),
          const SizedBox(height: 8),
          PdfExportButton(
            filename: 'pediatric',
            tabTitleKey: 'tab_pediatric',
            buildSections: () => [
              PdfSection(title: t('pdf_inputs'), rows: [
                PdfRow.numeric(label: t('bsa_body_weight'), value: patientData.pediatricWeight,    unit: 'kg'),
                PdfRow.numeric(label: t('ped_desired_hb'),  value: patientData.desiredHbIncrease, unit: 'g/dl', decimals: 1),
              ]),
              PdfSection(title: t('pdf_results'), rows: [
                PdfRow.numeric(label: t('ped_transfusion_vol'), value: patientData.transfusionVolume, unit: 'ml', decimals: 0,
                    note: t('ped_hct_in_ek')),
              ]),
            ],
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
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(children: [
        Container(
          decoration: const BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: headers.asMap().entries.map((e) =>
            Expanded(flex: flexes[e.key],
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Text(e.value, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13))))).toList()),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key; final r = e.value; final isLast = i == rows.length - 1;
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? const Color(0xFF222222) : const Color(0xFF1A1A1A),
              borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : BorderRadius.zero,
              border: isLast ? null : const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(children: r.asMap().entries.map((ce) =>
              Expanded(flex: flexes[ce.key],
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(ce.value, style: TextStyle(
                    color: ce.key == 0 ? kGold : Colors.white,
                    fontSize: 14,
                    fontWeight: ce.key == 0 ? FontWeight.w600 : FontWeight.normal))))).toList()),
          );
        }),
      ]),
    );
  }
}
