import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';

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
        const SourceButton(refs: [
          AppSources.barrettBoyes,
          AppSources.skimming,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }
}
