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
}

// ── PDF-Sections (extrahiert, für Einzel-Export und Gesamtbericht) ─────────
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
