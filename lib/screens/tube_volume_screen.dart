import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';

class TubeVolumeScreen extends StatelessWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const TubeVolumeScreen({super.key, required this.patientData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),
        InputCard(label: 'Tube length', unit: 'cm', value: patientData.tubeLength,
            step: 1, onChanged: (v) { patientData.tubeLength = v; onChanged(); }),
        const SectionHeader('Fill volume per cm \u00d7 length (ml)'),
        ResultCard(label: '1/2"',  unit: 'ml', value: patientData.tubeVol12,  decimals: 1),
        ResultCard(label: '3/8"',  unit: 'ml', value: patientData.tubeVol38,  decimals: 1),
        ResultCard(label: '1/4"',  unit: 'ml', value: patientData.tubeVol14,  decimals: 1),
        ResultCard(label: '3/16"', unit: 'ml', value: patientData.tubeVol316, decimals: 1),
        const SizedBox(height: 8),
        const SourceButton(refs: [
          AppSources.tschaut,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }
}
