import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';

class PediatricScreen extends StatelessWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const PediatricScreen({super.key, required this.patientData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 10),
          _sectionTitle('Tube diameter (Darling et al. 2000)'),
          const SizedBox(height: 8),
          _fancyTable(
            headers: ['Weight (kg)', 'Art. Line', 'Ven. Line'],
            rows: const [
              ['0 \u2013 3', '3/16"', '3/16"'], ['3 \u2013 5', '3/16"', '1/4"'],
              ['6 \u2013 10', '1/4"', '1/4"'],  ['11 \u2013 30', '1/4"', '3/8"'],
              ['31 \u2013 50', '3/8"', '3/8"'], ['> 50', '3/8"', '1/2"'],
            ],
            flexes: [3, 2, 2],
          ),
          const SizedBox(height: 16),
          _sectionTitle('Perfusion rate (Tschaut 2020)'),
          const SizedBox(height: 8),
          _fancyTable(
            headers: ['Weight (kg)', 'Flow (ml/kg/min)'],
            rows: const [
              ['0 \u2013 3', '120 \u2013 200'], ['3 \u2013 10', '125 \u2013 175'],
              ['10 \u2013 30', '120 \u2013 150'], ['30 \u2013 50', '75 \u2013 100'],
              ['> 55', '65'],
            ],
            flexes: [2, 3],
          ),
          const SizedBox(height: 16),
          ImageSectionCard(title: 'V-A cannula size (Finck 2020)', assetPath: 'assets/finck_va.jpg'),
          const SizedBox(height: 8),
          ImageSectionCard(title: 'V-V cannula size (Finck 2020)', assetPath: 'assets/finck_vv.jpg'),
          const SizedBox(height: 16),
          _sectionTitle('Pediatric blood volume'),
          const SizedBox(height: 8),
          InputCard(label: 'Body weight', unit: 'kg', value: patientData.pediatricWeight,
              onChanged: (v) { patientData.pediatricWeight = v; onChanged(); }),
          _bvResult('Premature infants',    100),
          _bvResult('Babies < 3 months',    85),
          _bvResult('Children \u2265 3 months', 75),
          _bvResult('Male adolescents',     70),
          _bvResult('Female adolescents',   65),
          const SizedBox(height: 16),
          _sectionTitle('Transfusion volume'),
          const SizedBox(height: 8),
          InputCard(label: 'Desired Hb increase', unit: 'g/dl', value: patientData.desiredHbIncrease,
              onChanged: (v) { patientData.desiredHbIncrease = v; onChanged(); }),
          ResultCard(label: 'Transfusion volume', unit: 'ml', value: patientData.transfusionVolume,
              rangeHint: 'Hct in EK = 55%', decimals: 0),
          const SizedBox(height: 8),
          const SourceButton(refs: [
            AppSources.darling,
            AppSources.tschaut,
            AppSources.finck,
            AppSources.hazinski,
            AppSources.howie,
            AppSources.davies,
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) =>
      Text(t, style: const TextStyle(color: kGold, fontSize: 15, fontWeight: FontWeight.bold));

  Widget _bvResult(String label, double factor) {
    final w = patientData.pediatricWeight ?? 0;
    return ResultCard(label: '$label (${factor.toInt()} ml/kg)', unit: 'ml', value: w * factor, decimals: 0);
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
