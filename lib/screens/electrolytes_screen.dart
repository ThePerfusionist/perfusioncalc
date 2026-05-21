import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

class ElectrolytesScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const ElectrolytesScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<ElectrolytesScreen> createState() => _ElectrolytesScreenState();
}

class _ElectrolytesScreenState extends State<ElectrolytesScreen> {
  PatientData get patientData => widget.patientData;

  /// Lokaler Rebuild: aktualisiert nur diesen Screen, nicht den ganzen
  /// MainScreen. Anschließend wird der (No-Op-)Parent-Callback informiert.
  void onChanged() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // Helper-Listen pro Formel - sammeln die fehlenden Pflichteingaben.
    // Wenn auch nur eine fehlt, wird "—" statt einer Zahl angezeigt.
    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final hWeight  = (v: patientData.bodyWeightElec, label: t('bsa_body_weight'));
    final hNaIst   = (v: patientData.natriumIst,     label: t('elec_sodium_current'));
    final hNaSoll  = (v: patientData.natriumSoll,    label: t('elec_sodium_target'));
    final hKIst    = (v: patientData.kaliumIst,      label: t('elec_potassium_current'));
    final hKSoll   = (v: patientData.kaliumSoll,     label: t('elec_potassium_target'));
    final hCaIst   = (v: patientData.calziumIst,     label: t('elec_calcium_current'));
    final hCaSoll  = (v: patientData.calziumSoll,    label: t('elec_calcium_target'));
    final hBE      = (v: patientData.baseExcess,     label: t('elec_base_excess'));

    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),
        InputCard(label: t('bsa_body_weight'), unit: 'kg', value: patientData.bodyWeightElec,
            range: Ranges.weight,
            onChanged: (v) { patientData.bodyWeightElec = v; onChanged(); }),
        SectionHeader(t('elec_section_sodium')),
        InputCard(label: t('elec_sodium_current'), unit: 'mmol', value: patientData.natriumIst,
            range: Ranges.natrium,
            onChanged: (v) { patientData.natriumIst = v; onChanged(); }),
        InputCard(label: t('elec_sodium_target'), unit: 'mmol', value: patientData.natriumSoll,
            range: Ranges.natrium,
            onChanged: (v) { patientData.natriumSoll = v; onChanged(); }),
        ResultCard(label: t('elec_sodium_need'), unit: 'ml NaCl 10%', value: patientData.natriumBedarf,
            missingInputs: missing([hWeight, hNaIst, hNaSoll])),
        SectionHeader(t('elec_section_potassium')),
        InputCard(label: t('elec_potassium_current'), unit: 'mmol', value: patientData.kaliumIst,
            range: Ranges.kalium,
            onChanged: (v) { patientData.kaliumIst = v; onChanged(); }),
        InputCard(label: t('elec_potassium_target'), unit: 'mmol', value: patientData.kaliumSoll,
            range: Ranges.kalium,
            onChanged: (v) { patientData.kaliumSoll = v; onChanged(); }),
        ResultCard(label: t('elec_potassium_need'), unit: 'ml KCl 7,45%', value: patientData.kaliumBedarf,
            missingInputs: missing([hWeight, hKIst, hKSoll])),
        SectionHeader(t('elec_section_calcium')),
        InputCard(label: t('elec_calcium_current'), unit: 'mmol', value: patientData.calziumIst,
            range: Ranges.calzium,
            onChanged: (v) { patientData.calziumIst = v; onChanged(); }),
        InputCard(label: t('elec_calcium_target'), unit: 'mmol', value: patientData.calziumSoll,
            range: Ranges.calzium,
            onChanged: (v) { patientData.calziumSoll = v; onChanged(); }),
        ResultCard(label: t('elec_calcium_need'), unit: 'ml Ca.gluc. 10%', value: patientData.calziumBedarf,
            missingInputs: missing([hWeight, hCaIst, hCaSoll])),
        SectionHeader(t('elec_section_buffer')),
        InputCard(label: t('elec_base_excess'), unit: 'mmol/L', value: patientData.baseExcess,
            range: Ranges.baseExcess,
            onChanged: (v) { patientData.baseExcess = v; onChanged(); }),
        ResultCard(label: 'NaBic 8,4%', unit: 'ml', value: patientData.nabic,
            missingInputs: missing([hWeight, hBE])),
        ResultCard(label: 'TRIS 36,34%', unit: 'ml', value: patientData.tris,
            missingInputs: missing([hWeight, hBE])),
        const SizedBox(height: 8),
        PdfExportButton(
          filename: 'electrolytes',
          tabTitleKey: 'tab_electrolytes',
          buildSections: () => [
            PdfSection(title: t('pdf_inputs'), rows: [
              PdfRow.numeric(label: t('bsa_body_weight'),       value: patientData.bodyWeightElec, unit: 'kg'),
              PdfRow.numeric(label: t('elec_sodium_current'),   value: patientData.natriumIst,     unit: 'mmol'),
              PdfRow.numeric(label: t('elec_sodium_target'),    value: patientData.natriumSoll,    unit: 'mmol'),
              PdfRow.numeric(label: t('elec_potassium_current'),value: patientData.kaliumIst,      unit: 'mmol'),
              PdfRow.numeric(label: t('elec_potassium_target'), value: patientData.kaliumSoll,     unit: 'mmol'),
              PdfRow.numeric(label: t('elec_calcium_current'),  value: patientData.calziumIst,     unit: 'mmol'),
              PdfRow.numeric(label: t('elec_calcium_target'),   value: patientData.calziumSoll,    unit: 'mmol'),
              PdfRow.numeric(label: t('elec_base_excess'),      value: patientData.baseExcess,     unit: 'mmol/L'),
            ]),
            PdfSection(title: t('pdf_results'), rows: [
              PdfRow.numeric(label: t('elec_sodium_need'),    value: patientData.natriumBedarf, unit: 'ml NaCl 10%',     decimals: 1),
              PdfRow.numeric(label: t('elec_potassium_need'), value: patientData.kaliumBedarf,  unit: 'ml KCl 7,45%',    decimals: 1),
              PdfRow.numeric(label: t('elec_calcium_need'),   value: patientData.calziumBedarf, unit: 'ml Ca.gluc. 10%', decimals: 1),
              PdfRow.numeric(label: 'NaBic 8,4%',             value: patientData.nabic,         unit: 'ml',              decimals: 1),
              PdfRow.numeric(label: 'TRIS 36,34%',            value: patientData.tris,          unit: 'ml',              decimals: 1),
            ]),
          ],
        ),
        SourceButton(refs: [
          AppSources.mellemgaardAstrup1960,
          AppSources.nahas1959,
          AppSources.adrogueMadias2000,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }
}
