import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../i18n/app_strings.dart';

/// Eine Zeile der Referenztabelle: Bezeichnung, typischer Wert, Normbereich.
typedef RefRow = ({String label, String typical, String range});

/// Ein Abschnitt der Referenztabelle.
typedef RefSection = ({String title, List<RefRow> rows});

class ReferencePressureScreen extends StatelessWidget {
  const ReferencePressureScreen({super.key});

  // Records statt Map<String, dynamic> (Eigenbefund v0.4.12): die frueheren
  // Zugriffe brauchten `s['rows'] as List<List<String>>` und `s['title'] as
  // String`, und die Spalten wurden ueber r[0]/r[1]/r[2] adressiert. Ein
  // Tippfehler im Schluessel oder eine Zeile mit zu wenigen Spalten waere
  // erst zur Laufzeit aufgefallen - in einer Tabelle mit klinischen
  // Referenzwerten, die niemand nachrechnet, weil sie ja nur angezeigt wird.
  // Dieselbe Umstellung wie bei MainScreen.kTabs.
  //
  // Weiterhin eine Methode statt einer Konstanten: die Beschriftungen kommen
  // ueber t() und muessen bei jedem Sprachwechsel neu aufgeloest werden.
  List<RefSection> _sections() => [
    (
      title: t('ref_section_arterial'),
      rows: [
        (label: t('ref_systolic'), typical: '130 mmHg', range: '90 – 140 mmHg'),
        (label: t('ref_diastolic'), typical: '70 mmHg', range: '60 – 90 mmHg'),
        (label: t('ref_mean'), typical: '85 mmHg', range: '70 – 105 mmHg'),
      ],
    ),
    (
      title: t('ref_section_lv'),
      rows: [
        (label: t('ref_systolic'), typical: '130 mmHg', range: '90 – 140 mmHg'),
        (label: t('ref_diastolic'), typical: '7 mmHg', range: '4 – 12 mmHg'),
      ],
    ),
    (
      title: t('ref_section_la'),
      rows: [(label: t('ref_mean'), typical: '8 mmHg', range: '2 – 12 mmHg')],
    ),
    (
      title: t('ref_section_ra'),
      rows: [(label: t('ref_mean'), typical: '4 mmHg', range: '0 – 8 mmHg')],
    ),
    (
      title: t('ref_section_rv'),
      rows: [
        (label: t('ref_systolic'), typical: '24 mmHg', range: '15 – 28 mmHg'),
        (label: t('ref_diastolic'), typical: '4 mmHg', range: '0 – 8 mmHg'),
      ],
    ),
    (
      title: t('ref_section_pcwp'),
      rows: [(label: t('ref_mean'), typical: '9 mmHg', range: '6 – 18 mmHg')],
    ),
    (
      title: t('ref_section_pap'),
      rows: [
        (label: t('ref_systolic'), typical: '24 mmHg', range: '15 – 28 mmHg'),
        (label: t('ref_diastolic'), typical: '10 mmHg', range: '5 – 16 mmHg'),
        (label: t('ref_mean'), typical: '16 mmHg', range: '10 – 22 mmHg'),
      ],
    ),
    (
      title: t('ref_section_cvp'),
      rows: [
        (label: 'CVP', typical: '', range: '2 – 8 cmH\u2082O'),
        (label: t('ref_spontaneous'), typical: '', range: '1 – 6 mmHg'),
      ],
    ),
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
                      style:  TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.bold))),
                Expanded(flex: 3,
                  child: Text(t('ref_col_range'),
                      style:  TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.bold))),
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

  Widget _sectionCard(RefSection s) {
    final rows = s.rows;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceWash),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration:  BoxDecoration(
            color: kTableHeaderBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Text(s.title,
              style: const TextStyle(color: kGold, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final isLast = i == rows.length - 1;
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? kRowStripeA : kRowStripeB,
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: kText.withValues(alpha: 0.07))),
            ),
            child: Row(children: [
              Expanded(flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Text(r.label,
                      style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                  child: Text(r.typical, style:  TextStyle(color: kText, fontSize: 13)),
                ),
              ),
              Expanded(flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                  child: Text(r.range, style:  TextStyle(color: kText, fontSize: 13)),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
