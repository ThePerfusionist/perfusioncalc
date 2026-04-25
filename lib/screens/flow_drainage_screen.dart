import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../i18n/app_strings.dart';

class FlowDrainageScreen extends StatelessWidget {
  const FlowDrainageScreen({super.key});

  static const _rows = [
    ['3/16"', '< 1.3 l/min', '0.5 \u2013 0.65 l/min'],
    ['1/4"',  '< 3.0 l/min', '1.2 \u2013 1.6 l/min'],
    ['3/8"',  '> 5.0 l/min', '4.0 \u2013 4.5 l/min'],
    ['1/2"',  '> 5.0 l/min', '> 5.0 l/min'],
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text(t('flow_title'),
              style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Column(children: [
              Container(
                decoration: const BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: Row(children: [
                  _hCell(t('flow_col_tube'),         flex: 2),
                  _hCell(t('flow_col_max_flow'),     flex: 3),
                  _hCell(t('flow_col_max_drainage'), flex: 3),
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
          const SizedBox(height: 16),
          SourceButton(refs: [AppSources.tschaut]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _hCell(String text, {int flex = 1}) => Expanded(flex: flex,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(text, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13))));

  Widget _cell(String text, {int flex = 1, Color color = Colors.white, bool bold = false}) =>
    Expanded(flex: flex,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Text(text, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14))));
}
