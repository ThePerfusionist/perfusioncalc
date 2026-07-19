import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

class ResistancesScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const ResistancesScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<ResistancesScreen> createState() => _ResistancesScreenState();
}

class _ResistancesScreenState extends State<ResistancesScreen> {
  PatientData get patientData => widget.patientData;

  void onChanged() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final hMap     = (v: patientData.map,    label: 'MAP');
    final hCvp     = (v: patientData.cvp,    label: 'CVP');
    final hHzvRes  = (v: patientData.hzvRes, label: t('res_co_for_svr'));
    final hPap     = (v: patientData.pap,    label: 'PAP');
    final hLap     = (v: patientData.lap,    label: 'LAP');
    final hHzvPvr  = (v: patientData.hzvPvr, label: t('res_co_for_pvr'));

    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),
        InputCard(label: 'MAP', unit: 'mmHg', value: patientData.map,
            range: Ranges.map,
            onChanged: (v) { patientData.map = v; onChanged(); }),
        InputCard(label: 'CVP', unit: 'mmHg', value: patientData.cvp,
            range: Ranges.cvp,
            onChanged: (v) { patientData.cvp = v; onChanged(); }),
        InputCard(label: t('res_co_for_svr'), unit: 'l/min', value: patientData.hzvRes,
            range: Ranges.co,
            onChanged: (v) { patientData.hzvRes = v; onChanged(); }),
        ResultCard(label: 'SVR', unit: 'dyns/cm\u2075', value: patientData.svr,
            rangeHint: '(900-1200 dyns/cm\u2075)', decimals: 0,
            missingInputs: missing([hMap, hCvp, hHzvRes])),
        InputCard(label: 'PAP', unit: 'mmHg', value: patientData.pap,
            range: Ranges.pap,
            onChanged: (v) { patientData.pap = v; onChanged(); }),
        InputCard(label: 'LAP', unit: 'mmHg', value: patientData.lap,
            range: Ranges.lap,
            onChanged: (v) { patientData.lap = v; onChanged(); }),
        InputCard(label: t('res_co_for_pvr'), unit: 'l/min', value: patientData.hzvPvr,
            range: Ranges.co,
            onChanged: (v) { patientData.hzvPvr = v; onChanged(); }),
        ResultCard(label: 'PVR', unit: 'dyns/cm\u2075', value: patientData.pvr,
            rangeHint: '(150-300 dyns/cm\u2075)', decimals: 0,
            missingInputs: missing([hPap, hLap, hHzvPvr])),
        const SizedBox(height: 8),
        PdfExportButton(
          filename: 'resistances',
          tabTitleKey: 'tab_resistances',
          buildSections: () => buildResistancesPdfSections(patientData),
        ),
        SourceButton(refs: [
          AppSources.barrettBoyes,
          AppSources.skimming,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ── PDF-Sections (extrahiert, für Einzel-Export und Gesamtbericht) ─────────
List<PdfSection> buildResistancesPdfSections(PatientData pd) => [
  PdfSection(title: t('pdf_inputs'), rows: [
    PdfRow.numeric(label: 'MAP',                value: pd.map,    unit: 'mmHg'),
    PdfRow.numeric(label: 'CVP',                value: pd.cvp,    unit: 'mmHg'),
    PdfRow.numeric(label: t('res_co_for_svr'),  value: pd.hzvRes, unit: 'l/min'),
    PdfRow.numeric(label: 'PAP',                value: pd.pap,    unit: 'mmHg'),
    PdfRow.numeric(label: 'LAP',                value: pd.lap,    unit: 'mmHg'),
    PdfRow.numeric(label: t('res_co_for_pvr'),  value: pd.hzvPvr, unit: 'l/min'),
  ]),
  PdfSection(title: t('pdf_results'), rows: [
    PdfRow.numeric(label: 'SVR', value: pd.svr, unit: 'dyns/cm\u2075', decimals: 0),
    PdfRow.numeric(label: 'PVR', value: pd.pvr, unit: 'dyns/cm\u2075', decimals: 0),
  ]),
];
