import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

class TubeVolumeScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const TubeVolumeScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<TubeVolumeScreen> createState() => _TubeVolumeScreenState();
}

class _TubeVolumeScreenState extends State<TubeVolumeScreen> {
  PatientData get patientData => widget.patientData;

  void onChanged() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  // Reference table merged in from the former standalone Flow/Drainage-rate
  // tab. Static reference values (not patient-specific), so they don't
  // appear in the PDF export - same treatment as the other pure reference
  // tabs (e.g. ReferencePressureScreen).
  static const _flowRows = [
    ['3/16"', '< 1.3 l/min', '0.5 \u2013 0.65 l/min'],
    ['1/4"',  '< 3.0 l/min', '1.2 \u2013 1.6 l/min'],
    ['3/8"',  '> 5.0 l/min', '4.0 \u2013 4.5 l/min'],
    ['1/2"',  '> 5.0 l/min', '> 5.0 l/min'],
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),
        InputCard(label: t('tube_length'), unit: 'cm', value: patientData.tubeLength,
            range: Ranges.tubeLength,
            step: 1, onChanged: (v) { patientData.tubeLength = v; onChanged(); }),
        SectionHeader(t('tube_section_fill')),
        Builder(builder: (_) {
          final missing = patientData.tubeLength == null ? [t('tube_length')] : const <String>[];
          return Column(children: [
            ResultCard(label: '1/2"',  unit: 'ml', value: patientData.tubeVol12,  decimals: 1, missingInputs: missing),
            ResultCard(label: '3/8"',  unit: 'ml', value: patientData.tubeVol38,  decimals: 1, missingInputs: missing),
            ResultCard(label: '1/4"',  unit: 'ml', value: patientData.tubeVol14,  decimals: 1, missingInputs: missing),
            ResultCard(label: '3/16"', unit: 'ml', value: patientData.tubeVol316, decimals: 1, missingInputs: missing),
          ]);
        }),
        SectionHeader(t('flow_title')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kDivider)),
            child: Column(children: [
              Container(
                decoration:  BoxDecoration(color: kTableHeaderBg, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: Row(children: [
                  _hCell(t('flow_col_tube'),         flex: 2),
                  _hCell(t('flow_col_max_flow'),     flex: 3),
                  _hCell(t('flow_col_max_drainage'), flex: 3),
                ]),
              ),
              ..._flowRows.asMap().entries.map((e) {
                final i = e.key; final r = e.value; final isLast = i == _flowRows.length - 1;
                return Container(
                  decoration: BoxDecoration(
                    color: i.isOdd ? kRowStripeA : kRowStripeB,
                    borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : BorderRadius.zero,
                    border: isLast ? null :  Border(bottom: BorderSide(color: kSurfaceWash)),
                  ),
                  child: Row(children: [
                    _flowCell(r[0], flex: 2, color: kGold, bold: true),
                    _flowCell(r[1], flex: 3),
                    _flowCell(r[2], flex: 3),
                  ]),
                );
              }),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        PdfExportButton(
          filename: 'tube_volume',
          tabTitleKey: 'tab_tube_volume',
          buildSections: () => buildTubeVolumePdfSections(patientData),
        ),
        SourceButton(refs: [
          AppSources.oldeen2020,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _hCell(String text, {int flex = 1}) => Expanded(flex: flex,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(text, style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13))));

  Widget _flowCell(String text, {int flex = 1, Color? color, bool bold = false}) =>
    Expanded(flex: flex,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Text(text, style: TextStyle(color: color ?? kText, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14))));
}

// ── PDF sections (extracted, for the single-tab export and the combined report) ─
List<PdfSection> buildTubeVolumePdfSections(PatientData pd) => [
  PdfSection(title: t('pdf_inputs'), rows: [
    PdfRow.numeric(label: t('tube_length'), value: pd.tubeLength, unit: 'cm', decimals: 0),
  ]),
  PdfSection(title: t('pdf_results'), rows: [
    PdfRow.numeric(label: '1/2"',  value: pd.tubeVol12,  unit: 'ml', decimals: 1),
    PdfRow.numeric(label: '3/8"',  value: pd.tubeVol38,  unit: 'ml', decimals: 1),
    PdfRow.numeric(label: '1/4"',  value: pd.tubeVol14,  unit: 'ml', decimals: 1),
    PdfRow.numeric(label: '3/16"', value: pd.tubeVol316, unit: 'ml', decimals: 1),
  ]),
];
