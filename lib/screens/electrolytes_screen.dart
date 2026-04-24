import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';

class ElectrolytesScreen extends StatelessWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const ElectrolytesScreen({super.key, required this.patientData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),
        InputCard(label: 'Body weight', unit: 'kg', value: patientData.bodyWeightElec,
            range: Ranges.weight,
            onChanged: (v) { patientData.bodyWeightElec = v; onChanged(); }),
        const SectionHeader('Sodium'),
        InputCard(label: 'Sodium current', unit: 'mmol', value: patientData.natriumIst,
            range: Ranges.natrium,
            onChanged: (v) { patientData.natriumIst = v; onChanged(); }),
        InputCard(label: 'Sodium target', unit: 'mmol', value: patientData.natriumSoll,
            range: Ranges.natrium,
            onChanged: (v) { patientData.natriumSoll = v; onChanged(); }),
        ResultCard(label: 'Sodium need', unit: 'ml NaCl 10%', value: patientData.natriumBedarf),
        const SectionHeader('Potassium'),
        InputCard(label: 'Potassium current', unit: 'mmol', value: patientData.kaliumIst,
            range: Ranges.kalium,
            onChanged: (v) { patientData.kaliumIst = v; onChanged(); }),
        InputCard(label: 'Potassium target', unit: 'mmol', value: patientData.kaliumSoll,
            range: Ranges.kalium,
            onChanged: (v) { patientData.kaliumSoll = v; onChanged(); }),
        ResultCard(label: 'Potassium need', unit: 'ml KCl 7,45%', value: patientData.kaliumBedarf),
        const SectionHeader('Calcium'),
        InputCard(label: 'Calcium current', unit: 'mmol', value: patientData.calziumIst,
            range: Ranges.calzium,
            onChanged: (v) { patientData.calziumIst = v; onChanged(); }),
        InputCard(label: 'Calcium target', unit: 'mmol', value: patientData.calziumSoll,
            range: Ranges.calzium,
            onChanged: (v) { patientData.calziumSoll = v; onChanged(); }),
        ResultCard(label: 'Calcium need', unit: 'ml Ca.gluc. 10%', value: patientData.calziumBedarf),
        const SectionHeader('Buffer'),
        InputCard(label: 'Base Excess', unit: 'mmol/L', value: patientData.baseExcess,
            range: Ranges.baseExcess,
            onChanged: (v) { patientData.baseExcess = v; onChanged(); }),
        ResultCard(label: 'NaBic 8,4%', unit: 'ml', value: patientData.nabic),
        ResultCard(label: 'TRIS 36,34%', unit: 'ml', value: patientData.tris),
        const SizedBox(height: 8),
        const SourceButton(refs: [
          AppSources.larsen,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }
}
