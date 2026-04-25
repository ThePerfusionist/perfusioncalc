import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../i18n/app_strings.dart';

class ReferencePressureScreen extends StatelessWidget {
  const ReferencePressureScreen({super.key});

  // Sections sind dynamisch, damit die Sprache umgeschaltet werden kann.
  // 'title' kommt jeweils per t() pro Build-Aufruf.
  List<Map<String, dynamic>> _sections() => [
    {
      'title': t('ref_section_arterial'),
      'rows': [
        [t('ref_systolic'),  '130 mmHg', '90 – 140 mmHg'],
        [t('ref_diastolic'), '70 mmHg',  '60 – 90 mmHg'],
        [t('ref_mean'),      '85 mmHg',  '70 – 105 mmHg'],
      ],
    },
    {
      'title': t('ref_section_lv'),
      'rows': [
        [t('ref_systolic'),  '130 mmHg', '90 – 140 mmHg'],
        [t('ref_diastolic'), '7 mmHg',   '4 – 12 mmHg'],
      ],
    },
    {
      'title': t('ref_section_la'),
      'rows': [[t('ref_mean'), '8 mmHg', '2 – 12 mmHg']],
    },
    {
      'title': t('ref_section_ra'),
      'rows': [[t('ref_mean'), '4 mmHg', '0 – 8 mmHg']],
    },
    {
      'title': t('ref_section_rv'),
      'rows': [
        [t('ref_systolic'),  '24 mmHg', '15 – 28 mmHg'],
        [t('ref_diastolic'), '4 mmHg',  '0 – 8 mmHg'],
      ],
    },
    {
      'title': t('ref_section_pcwp'),
      'rows': [[t('ref_mean'), '9 mmHg', '6 – 18 mmHg']],
    },
    {
      'title': t('ref_section_pap'),
      'rows': [
        [t('ref_systolic'),  '24 mmHg', '15 – 28 mmHg'],
        [t('ref_diastolic'), '10 mmHg', '5 – 16 mmHg'],
        [t('ref_mean'),      '16 mmHg', '10 – 22 mmHg'],
      ],
    },
    {
      'title': t('ref_section_cvp'),
      'rows': [
        ['CVP',                  '', '2 – 8 cmH\u2082O'],
        [t('ref_spontaneous'),   '', '1 – 6 mmHg'],
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
            Text(t('ref_title_main'),
                style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // Column headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                const Expanded(flex: 4, child: SizedBox()),
                Expanded(flex: 3,
                  child: Text(t('ref_col_normal'),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                Expanded(flex: 3,
                  child: Text(t('ref_col_range'),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
              ]),
            ),
            const SizedBox(height: 4),
            ..._sections().map((s) => _sectionCard(s)),
            SourceButton(refs: [
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF252525),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Text(s['title'] as String,
              style: const TextStyle(color: kGold, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
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
              Expanded(flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Text(r[0],
                      style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                  child: Text(r[1], style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
              Expanded(flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                  child: Text(r[2], style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
