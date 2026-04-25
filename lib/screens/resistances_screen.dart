import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

class ResistancesScreen extends StatelessWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const ResistancesScreen({super.key, required this.patientData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
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
            rangeHint: '(900-1200 dyns/cm\u2075)', decimals: 0),
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
            rangeHint: '(150-300 dyns/cm\u2075)', decimals: 0),
        const SizedBox(height: 8),
        PdfExportButton(
          filename: 'resistances',
          tabTitleKey: 'tab_resistances',
          buildSections: () => [
            PdfSection(title: t('pdf_inputs'), rows: [
              PdfRow.numeric(label: 'MAP',                value: patientData.map,    unit: 'mmHg'),
              PdfRow.numeric(label: 'CVP',                value: patientData.cvp,    unit: 'mmHg'),
              PdfRow.numeric(label: t('res_co_for_svr'),  value: patientData.hzvRes, unit: 'l/min'),
              PdfRow.numeric(label: 'PAP',                value: patientData.pap,    unit: 'mmHg'),
              PdfRow.numeric(label: 'LAP',                value: patientData.lap,    unit: 'mmHg'),
              PdfRow.numeric(label: t('res_co_for_pvr'),  value: patientData.hzvPvr, unit: 'l/min'),
            ]),
            PdfSection(title: t('pdf_results'), rows: [
              PdfRow.numeric(label: 'SVR', value: patientData.svr, unit: 'dyns/cm\u2075', decimals: 0),
              PdfRow.numeric(label: 'PVR', value: patientData.pvr, unit: 'dyns/cm\u2075', decimals: 0),
            ]),
          ],
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
