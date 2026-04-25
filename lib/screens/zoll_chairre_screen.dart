import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';

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
          Text(t('zoll_title_diameter'),
              style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Column(children: [
              Container(
                decoration: const BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: Row(children: [
                  _hCell(t('zoll_col_size'),      flex: 2),
                  _hCell(t('zoll_col_diameter'),  flex: 3),
                  _hCell(t('zoll_col_charriere'), flex: 3),
                ]),
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
          Text(t('zoll_converter_title'),
              style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          InputCard(label: t('zoll_ch_to_mm'), unit: 'Ch', value: patientData.chInput,
              range: Ranges.ch,
              onChanged: (v) { patientData.chInput = v; onChanged(); }),
          ResultCard(label: t('zoll_result_mm'), unit: 'mm', value: patientData.chToMm, decimals: 4),
          InputCard(label: t('zoll_mm_to_ch'), unit: 'mm', value: patientData.mmInput,
              range: Ranges.mm,
              onChanged: (v) { patientData.mmInput = v; onChanged(); }),
          ResultCard(label: t('zoll_result_ch'), unit: 'Ch', value: patientData.mmToCh, decimals: 1),
          const SizedBox(height: 16),
          const SourceButton(refs: [AppSources.tschaut]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Renamed parameter from "t" to "text" to avoid shadowing the global t() helper.
  Widget _hCell(String text, {int flex = 1}) => Expanded(flex: flex,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(text, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13))));

  Widget _cell(String text, {int flex = 1, Color color = Colors.white, bool bold = false}) =>
    Expanded(flex: flex,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Text(text, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14))));
}
