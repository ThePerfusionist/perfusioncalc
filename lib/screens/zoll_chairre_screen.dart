import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';

class ZollChairreScreen extends StatelessWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const ZollChairreScreen({super.key, required this.patientData, required this.onChanged});

  static const _rows = [
    ['3/16"', '4.7625 mm', '14.3 Ch'],
    ['1/4"',  '6.35 mm',   '19.1 Ch'],
    ['3/8"',  '9.525 mm',  '28.6 Ch'],
    ['1/2"',  '12.7 mm',   '38.1 Ch'],
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          const Text('Tube Diameter Reference',
              style: TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Column(children: [
              Container(
                decoration: const BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: Row(children: [_hCell('Size', flex: 2), _hCell('Diameter', flex: 3), _hCell('Charriere', flex: 3)]),
              ),
              ..._rows.asMap().entries.map((e) {
                final i = e.key; final r = e.value; final isLast = i == _rows.length - 1;
                return Container(
                  decoration: BoxDecoration(
                    color: i.isOdd ? const Color(0xFF222222) : const Color(0xFF1A1A1A),
                    borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : BorderRadius.zero,
                    border: isLast ? null : const Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(children: [
                    _cell(r[0], flex: 2, color: kGold, bold: true),
                    _cell(r[1], flex: 3),
                    _cell(r[2], flex: 3),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Charriere Converter',
              style: TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          InputCard(label: 'Charriere to millimeter', unit: 'Ch', value: patientData.chInput,
              onChanged: (v) { patientData.chInput = v; onChanged(); }),
          ResultCard(label: 'Millimeter', unit: 'mm', value: patientData.chToMm, decimals: 4),
          InputCard(label: 'Millimeter to Charriere', unit: 'mm', value: patientData.mmInput,
              onChanged: (v) { patientData.mmInput = v; onChanged(); }),
          ResultCard(label: 'Charriere', unit: 'Ch', value: patientData.mmToCh, decimals: 1),
          const SizedBox(height: 16),
          const SourceButton(refs: [AppSources.tschaut]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _hCell(String t, {int flex = 1}) => Expanded(flex: flex,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(t, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13))));

  Widget _cell(String t, {int flex = 1, Color color = Colors.white, bool bold = false}) =>
    Expanded(flex: flex,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Text(t, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14))));
}
