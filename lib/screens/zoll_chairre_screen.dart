import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

class ZollChairreScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const ZollChairreScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<ZollChairreScreen> createState() => _ZollChairreScreenState();
}

class _ZollChairreScreenState extends State<ZollChairreScreen> {
  PatientData get patientData => widget.patientData;

  void onChanged() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

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
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kDivider)),
            child: Column(children: [
              Container(
                decoration:  BoxDecoration(color: kTableHeaderBg, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
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
                    color: i.isOdd ? kRowStripeA : kRowStripeB,
                    borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : BorderRadius.zero,
                    border: isLast ? null :  Border(bottom: BorderSide(color: kSurfaceWash)),
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
          ResultCard(label: t('zoll_result_mm'), unit: 'mm', value: patientData.chToMm, decimals: 4,
              missingInputs: patientData.chInput == null ? [t('zoll_ch_to_mm')] : const []),
          InputCard(label: t('zoll_mm_to_ch'), unit: 'mm', value: patientData.mmInput,
              range: Ranges.mm,
              onChanged: (v) { patientData.mmInput = v; onChanged(); }),
          ResultCard(label: t('zoll_result_ch'), unit: 'Ch', value: patientData.mmToCh, decimals: 1,
              missingInputs: patientData.mmInput == null ? [t('zoll_mm_to_ch')] : const []),
          const SizedBox(height: 16),
          PdfExportButton(
            filename: 'zoll_charriere',
            tabTitleKey: 'tab_zoll',
            buildSections: () => [
              PdfSection(title: t('pdf_inputs'), rows: [
                PdfRow.numeric(label: t('zoll_ch_to_mm'), value: patientData.chInput, unit: 'Ch', decimals: 1),
                PdfRow.numeric(label: t('zoll_mm_to_ch'), value: patientData.mmInput, unit: 'mm', decimals: 2),
              ]),
              PdfSection(title: t('pdf_results'), rows: [
                PdfRow.numeric(label: t('zoll_result_mm'), value: patientData.chToMm, unit: 'mm', decimals: 4),
                PdfRow.numeric(label: t('zoll_result_ch'), value: patientData.mmToCh, unit: 'Ch', decimals: 1),
              ]),
            ],
          ),
          SourceButton(refs: [AppSources.oldeen2020]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Renamed parameter from "t" to "text" to avoid shadowing the global t() helper.
  Widget _hCell(String text, {int flex = 1}) => Expanded(flex: flex,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(text, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 13))));

  Widget _cell(String text, {int flex = 1, Color? color, bool bold = false}) =>
    Expanded(flex: flex,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Text(text, style: TextStyle(color: color ?? kText, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14))));
}
