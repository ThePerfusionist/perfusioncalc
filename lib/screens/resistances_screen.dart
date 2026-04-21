import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';

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
            onChanged: (v) { patientData.map = v; onChanged(); }),
        InputCard(label: 'CVP', unit: 'mmHg', value: patientData.cvp,
            onChanged: (v) { patientData.cvp = v; onChanged(); }),
        InputCard(label: 'Cardiac output (for SVR)', unit: 'l/min', value: patientData.hzvRes,
            onChanged: (v) { patientData.hzvRes = v; onChanged(); }),
        ResultCard(label: 'SVR', unit: 'dyns/cm\u2075', value: patientData.svr,
            rangeHint: '(900-1200 dyns/cm\u2075)', decimals: 0),
        InputCard(label: 'PAP', unit: 'mmHg', value: patientData.pap,
            onChanged: (v) { patientData.pap = v; onChanged(); }),
        InputCard(label: 'LAP', unit: 'mmHg', value: patientData.lap,
            onChanged: (v) { patientData.lap = v; onChanged(); }),
        InputCard(label: 'Cardiac output (for PVR)', unit: 'l/min', value: patientData.hzvPvr,
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
