import 'package:flutter/material.dart';
import '../widgets/common.dart';

class ReferencePressureScreen extends StatelessWidget {
  const ReferencePressureScreen({super.key});

  static const _sections = [
    {
      'title': 'Arterial pressure (AP)',
      'rows': [
        ['Systolic',      '130 mmHg', '90 – 140 mmHg'],
        ['Diastolic',     '70 mmHg',  '60 – 90 mmHg'],
        ['Mean pressure', '85 mmHg',  '70 – 105 mmHg'],
      ],
    },
    {
      'title': 'Left Ventricle (LV)',
      'rows': [
        ['Systolic',  '130 mmHg', '90 – 140 mmHg'],
        ['Diastolic', '7 mmHg',   '4 – 12 mmHg'],
      ],
    },
    {
      'title': 'Left Atrium (LA)',
      'rows': [
        ['Mean pressure', '8 mmHg', '2 – 12 mmHg'],
      ],
    },
    {
      'title': 'Right Atrium (RA)',
      'rows': [
        ['Mean pressure', '4 mmHg', '0 – 8 mmHg'],
      ],
    },
    {
      'title': 'Right Ventricle (RV)',
      'rows': [
        ['Systolic',  '24 mmHg', '15 – 28 mmHg'],
        ['Diastolic', '4 mmHg',  '0 – 8 mmHg'],
      ],
    },
    {
      'title': 'Pulmonary Capillary Pressure (PCWP)',
      'rows': [
        ['Mean pressure', '9 mmHg', '6 – 18 mmHg'],
      ],
    },
    {
      'title': 'Pulmonary Artery (PAP)',
      'rows': [
        ['Systolic',      '24 mmHg', '15 – 28 mmHg'],
        ['Diastolic',     '10 mmHg', '5 – 16 mmHg'],
        ['Mean pressure', '16 mmHg', '10 – 22 mmHg'],
      ],
    },
    {
      'title': 'Central Venous Pressure',
      'rows': [
        ['CVP',                   '', '2 – 8 cmH\u2082O'],
        ['Spontaneous breathing', '', '1 – 6 mmHg'],
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Reference Values – Pressure',
                style: TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // Column headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                const Expanded(flex: 4, child: SizedBox()),
                Expanded(
                  flex: 3,
                  child: Text('Normal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Range',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            ...(_sections as List<Map<String, dynamic>>).map((s) => _sectionCard(s)),
            const SourceButton(refs: [
              AppSources.barrettBoyes,
              AppSources.skimming,
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(Map<String, dynamic> s) {
    final rows = s['rows'] as List<List<String>>;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section title — gold
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF252525),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Text(s['title'] as String,
              style: const TextStyle(
                  color: kGold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
        // Data rows
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final isLast = i == rows.length - 1;
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? const Color(0xFF1E1E1E) : const Color(0xFF1A1A1A),
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
            ),
            child: Row(children: [
              // Left column — gold
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Text(r[0],
                      style: const TextStyle(
                          color: kGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              // Normal column — white
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                  child: Text(r[1],
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
              // Range column — white
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                  child: Text(r[2],
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
