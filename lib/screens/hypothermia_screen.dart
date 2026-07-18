import 'package:flutter/material.dart';
import '../models/bga_model.dart';
import '../widgets/common.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class HypothermiaScreen extends StatefulWidget {
  const HypothermiaScreen({super.key});
  @override
  State<HypothermiaScreen> createState() => _HypothermiaScreenState();
}

class _HypothermiaScreenState extends State<HypothermiaScreen> {
  final _model = BgaModel();
  void _rebuild() => setState(() {});

  // Table data: [Level, Range, Circulatory arrest, O2 requirement]
  // Dynamisch, damit Sprachwechsel die Level-Bezeichnungen aktualisiert.
  List<List<String>> _hypoRows() => [
    [t('hypo_lvl_light'),    '36 – 32 °C', '32 °C = 3–9 min',  '37 °C = 100%'],
    [t('hypo_lvl_moderate'), '32 – 28 °C', '28 °C = 9–15 min', '30 °C = 50%'],
    [t('hypo_lvl_deep'),     '28 – 18 °C', '18 °C = 45 min',   '25 °C = 25%'],
    [t('hypo_lvl_profound'), '18 – 4 °C',  '15 °C = 60 min',   '15 °C = 10%'],
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Hypothermia levels table ──────────────────────────────────────
          const SizedBox(height: 8),
          Text(t('hypo_title_levels'),
              style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _hypoTable(),

          // ── BGA temperature correction ────────────────────────────────────
          const SizedBox(height: 16),
          Text(t('hypo_title_bga'),
              style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _bgaSection(),

          // ── Source ────────────────────────────────────────────────────────
          const SizedBox(height: 8),
          SourceButton(refs: [
            AppSources.gocol2021,
            AppSources.severinghaus1979,
            AppSources.bradleySeveringhaus1956,
            AppSources.severinghaus1966,
            AppSources.ashwood1983,
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Hypothermia table (Flow/Drainage style) ───────────────────────────────
  Widget _hypoTable() {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDivider),
      ),
      child: Column(children: [
        // Header row
        Container(
          decoration:  BoxDecoration(
            color: kTableHeaderBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            _hCell(t('hypo_col_level'),  flex: 3),
            _hCell(t('hypo_col_range'),  flex: 3),
            _hCell(t('hypo_col_arrest'), flex: 3),
            _hCell(t('hypo_col_o2req'),  flex: 3),
          ]),
        ),
        // Data rows
        ..._hypoRows().asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final isLast = i == _hypoRows().length - 1;
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? kRowStripeA : kRowStripeB,
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
              border: isLast
                  ? null
                  :  Border(bottom: BorderSide(color: kSurfaceWash)),
            ),
            child: Row(children: [
              _cell(r[0], flex: 3, color: kGold, bold: true),
              _cell(r[1], flex: 3),
              _cell(r[2], flex: 3),
              _cell(r[3], flex: 3),
            ]),
          );
        }),
      ]),
    );
  }

  // ── BGA section ───────────────────────────────────────────────────────────
  Widget _bgaSection() {
    final hasCorrPaO2 = _model.corrPaO2 != null;
    final hasCorrCO2  = _model.corrPaCO2 != null;
    final hasCorrPH   = _model.corrPH != null;
    final anyResult   = hasCorrPaO2 || hasCorrCO2 || hasCorrPH;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Inputs ─────────────────────────────────────────────────────────────
      InputCard(
        label: t('hypo_temp'), unit: '°C',
        value: _model.temp, step: 0.1,
        range: Ranges.temperature,
        onChanged: (v) { _model.temp = v; _rebuild(); },
      ),
      InputCard(
        label: t('hypo_pao2'), unit: 'mmHg',
        value: _model.paO2, step: 1.0,
        range: Ranges.paO2,
        onChanged: (v) { _model.paO2 = v; _rebuild(); },
      ),
      InputCard(
        label: t('hypo_paco2'), unit: 'mmHg',
        value: _model.paCO2, step: 1.0,
        range: const Range(10, 100, 'mmHg', note: 'Normal 35–45'),
        onChanged: (v) { _model.paCO2 = v; _rebuild(); },
      ),
      InputCard(
        label: t('hypo_ph'), unit: '',
        value: _model.pH, step: 0.01,
        range: Ranges.pH,
        onChanged: (v) { _model.pH = v; _rebuild(); },
      ),

      // ── Hint if no results ────────────────────────────────────────────────
      if (!anyResult)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
             Icon(Icons.info_outline, color: kTextGhost, size: 14),
            const SizedBox(width: 6),
            Text(
              t('hypo_hint_enter'),
              style:  TextStyle(color: kTextFaint, fontSize: 12),
            ),
          ]),
        ),

      // ── Results ────────────────────────────────────────────────────────────
      if (anyResult) ...[
        SectionHeader(t('hypo_section_corrected')),

        if (hasCorrPaO2) ...[
          ResultCard(
            label: t('hypo_corr_pao2'),
            unit: 'mmHg',
            value: _model.corrPaO2!,
            decimals: 1,
            rangeHint: 'PO\u2082(T) = PO\u2082(37) \u00d7 e^(f\u1d40\u00d7\u0394T)  ·  Severinghaus 1979, Eq. 3',
          ),
          if (_model.fTPercent != null)
            _formulaHintCard(
              '${t('hypo_temp_coeff')} f\u1d40 = ${_model.fTPercent!.toStringAsFixed(2)} %/°C',
              t('hypo_temp_coeff_note'),
            ),
        ],

        if (hasCorrCO2)
          ResultCard(
            label: t('hypo_corr_paco2'),
            unit: 'mmHg',
            value: _model.corrPaCO2!,
            decimals: 1,
            rangeHint: 'PCO\u2082(T) = PCO\u2082(37) \u00d7 10^(0.0185\u00d7\u0394T)  ·  Bradley & Severinghaus 1956',
          ),

        if (hasCorrPH)
          ResultCard(
            label: t('hypo_corr_ph'),
            unit: '',
            value: _model.corrPH!,
            decimals: 3,
            rangeHint: 'pH(T) = pH(37) \u2212 0.0147 \u00d7 \u0394T  ·  Severinghaus & Bradley 1956',
          ),

        if (_model.hco3 != null)
          ResultCard(
            label: t('hypo_hco3'),
            unit: 'mmol/L',
            value: _model.hco3!,
            decimals: 1,
            rangeHint: 'HCO\u2083\u207b = 0.0307 \u00d7 PCO\u2082 \u00d7 10^(pH\u22126.105)  ·  Severinghaus 1966',
          ),

        if (_model.satFromPaO2 != null)
          ResultCard(
            label: t('hypo_sat'),
            unit: '%',
            value: _model.satFromPaO2!,
            decimals: 1,
            rangeHint: 'S = (23400\u00d7(PO\u2082\u00b3+150\u00d7PO\u2082)\u207b\u00b9 + 1)\u207b\u00b9  ·  Severinghaus 1979, Eq. 1',
          ),

        // Clinical thumb rules
        SectionHeader(t('hypo_section_thumb')),
        _thumbRuleTable(),
      ],

      // ── PDF Export Button (immer sichtbar) ─────────────────────────────
      const SizedBox(height: 8),
      PdfExportButton(
        filename: 'hypothermia',
        tabTitleKey: 'tab_hypothermia',
        buildSections: () => [
          PdfSection(title: t('pdf_inputs'), rows: [
            PdfRow.numeric(label: t('hypo_temp'),  value: _model.temp,  unit: '°C',   decimals: 1),
            PdfRow.numeric(label: t('hypo_pao2'),  value: _model.paO2,  unit: 'mmHg', decimals: 0),
            PdfRow.numeric(label: t('hypo_paco2'), value: _model.paCO2, unit: 'mmHg', decimals: 0),
            PdfRow.numeric(label: t('hypo_ph'),    value: _model.pH,    unit: '',     decimals: 2),
          ]),
          PdfSection(title: t('pdf_results'), rows: [
            PdfRow.numeric(label: t('hypo_corr_pao2'),  value: _model.corrPaO2,  unit: 'mmHg',  decimals: 1),
            PdfRow.numeric(label: t('hypo_corr_paco2'), value: _model.corrPaCO2, unit: 'mmHg',  decimals: 1),
            PdfRow.numeric(label: t('hypo_corr_ph'),    value: _model.corrPH,    unit: '',      decimals: 3),
            PdfRow.numeric(label: t('hypo_hco3'),       value: _model.hco3,      unit: 'mmol/L',decimals: 1),
            PdfRow.numeric(label: t('hypo_sat'),        value: _model.satFromPaO2, unit: '%',  decimals: 1),
          ]),
        ],
      ),
    ]);
  }

  // ── Thumb-rule table (same style as hypo table) ───────────────────────────
  Widget _thumbRuleTable() {
    final dT = _model.temp != null ? _model.temp! - 37.0 : null;

    String delta(double factor, int dec) {
      if (dT == null) return '–';
      final v = dT * factor;
      return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(dec)}';
    }

    final rows = [
      ['PaO\u2082',  '\u2212 5 mmHg / °C', delta(-5, 0),    'mmHg'],
      ['PaCO\u2082', '\u2212 2 mmHg / °C', delta(-2, 0),    'mmHg'],
      ['pH',         '+0.015 / °C',         delta(0.015, 3), ''],
    ];

    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDivider),
      ),
      child: Column(children: [
        Container(
          decoration:  BoxDecoration(
            color: kTableHeaderBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            _hCell(t('hypo_col_param'),  flex: 2),
            _hCell(t('hypo_col_rule'),   flex: 3),
            _hCell(t('hypo_col_dtotal'), flex: 2),
            _hCell(t('hypo_col_unit'),   flex: 2),
          ]),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final isLast = i == rows.length - 1;
          final isDelta = dT != null && r[2] != '–';
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? kRowStripeA : kRowStripeB,
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
              border: isLast
                  ? null
                  :  Border(bottom: BorderSide(color: kSurfaceWash)),
            ),
            child: Row(children: [
              _cell(r[0], flex: 2, color: kGold, bold: true),
              _cell(r[1], flex: 3),
              _cell(r[2], flex: 2,
                  color: isDelta ? kText : kTextFaint,
                  bold: isDelta),
              _cell(r[3], flex: 2, color: kTextMuted),
            ]),
          );
        }),
        // Source footnote
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration:  BoxDecoration(
            color: kRowStripeB,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child:  Text(
            'StatPearls NBK557769  ·  Deranged Physiology',
            style: TextStyle(color: kTextGhost, fontSize: 10),
          ),
        ),
      ]),
    );
  }

  // ── Small formula hint card ───────────────────────────────────────────────
  Widget _formulaHintCard(String main, String sub) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kRowStripeB,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
         Icon(Icons.functions, color: kTextGhost, size: 13),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(main, style:  TextStyle(color: kTextMuted, fontSize: 11)),
          Text(sub,  style:  TextStyle(color: kTextGhost, fontSize: 10)),
        ])),
      ]),
    );
  }

  // ── Table cell helpers (identical to Flow/Drainage pattern) ──────────────
  Widget _hCell(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(text,
          style: const TextStyle(
              color: kGold, fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );

  Widget _cell(String text, {int flex = 1, Color? color, bool bold = false}) =>
      Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(text,
              style: TextStyle(
                  color: color ?? kText,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13)),
        ),
      );
}
