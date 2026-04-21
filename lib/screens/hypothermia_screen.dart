import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Severinghaus temperature-correction model
// ─────────────────────────────────────────────────────────────────────────────
class _BgaModel {
  double? paO2;
  double? paCO2;
  double? pH;
  double? temp;

  double _fT(double po2) {
    final inner = 0.243 * pow(po2 / 100.0, 3.88) + 1.0;
    return 0.058 / inner + 0.013;
  }

  double? get corrPaO2 {
    if (paO2 == null || temp == null) return null;
    return paO2! * exp(_fT(paO2!) * (temp! - 37.0));
  }

  double? get corrPaCO2 {
    if (paCO2 == null || temp == null) return null;
    return paCO2! * pow(10.0, 0.0185 * (temp! - 37.0));
  }

  double? get corrPH {
    if (pH == null || temp == null) return null;
    return pH! - 0.0147 * (temp! - 37.0);
  }

  double? get satFromPaO2 {
    final p = corrPaO2 ?? paO2;
    if (p == null) return null;
    return 100.0 / (23400.0 / (pow(p, 3) + 150.0 * p) + 1.0);
  }

  double? get fTPercent {
    final p = corrPaO2 ?? paO2;
    if (p == null) return null;
    return _fT(p) * 100.0;
  }

  double? get hco3 {
    final co2c = corrPaCO2 ?? paCO2;
    final phc  = corrPH    ?? pH;
    if (co2c == null || phc == null) return null;
    return 0.0307 * co2c * pow(10.0, phc - 6.105);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class HypothermiaScreen extends StatefulWidget {
  const HypothermiaScreen({super.key});
  @override
  State<HypothermiaScreen> createState() => _HypothermiaScreenState();
}

class _HypothermiaScreenState extends State<HypothermiaScreen> {
  final _model = _BgaModel();
  void _rebuild() => setState(() {});

  // Table data: [Level, Range, Circulatory arrest, O2 requirement]
  static const _hypoRows = [
    ['Light (mild)', '36 – 32 °C', '32 °C = 3–9 min',  '37 °C = 100%'],
    ['Moderate',     '32 – 28 °C', '28 °C = 9–15 min', '30 °C = 50%'],
    ['Deep',         '28 – 18 °C', '18 °C = 45 min',   '25 °C = 25%'],
    ['Profound',     '18 – 4 °C',  '15 °C = 60 min',   '15 °C = 10%'],
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Hypothermia levels table ──────────────────────────────────────
          const SizedBox(height: 8),
          const Text('Hypothermia Levels',
              style: TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _hypoTable(),

          // ── BGA temperature correction ────────────────────────────────────
          const SizedBox(height: 16),
          const Text('BGA Temperature Correction',
              style: TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _bgaSection(),

          // ── Source ────────────────────────────────────────────────────────
          const SizedBox(height: 8),
          const SourceButton(refs: [
            AppSources.tschaut,
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
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: [
        // Header row
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            _hCell('Level',             flex: 3),
            _hCell('Range',             flex: 3),
            _hCell('Circ. arrest',      flex: 3),
            _hCell('O\u2082 req.',      flex: 3),
          ]),
        ),
        // Data rows
        ..._hypoRows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final isLast = i == _hypoRows.length - 1;
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? const Color(0xFF222222) : const Color(0xFF1A1A1A),
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: Colors.white10)),
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
        label: 'Patient temperature', unit: '°C',
        value: _model.temp, step: 0.1,
        onChanged: (v) { _model.temp = v; _rebuild(); },
      ),
      InputCard(
        label: 'PaO\u2082 (measured at 37 °C)', unit: 'mmHg',
        value: _model.paO2, step: 1.0,
        onChanged: (v) { _model.paO2 = v; _rebuild(); },
      ),
      InputCard(
        label: 'PaCO\u2082 (measured at 37 °C)', unit: 'mmHg',
        value: _model.paCO2, step: 1.0,
        onChanged: (v) { _model.paCO2 = v; _rebuild(); },
      ),
      InputCard(
        label: 'pH (measured at 37 °C)', unit: '',
        value: _model.pH, step: 0.01,
        onChanged: (v) { _model.pH = v; _rebuild(); },
      ),

      // ── Hint if no results ────────────────────────────────────────────────
      if (!anyResult)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: const [
            Icon(Icons.info_outline, color: Colors.white24, size: 14),
            SizedBox(width: 6),
            Text(
              'Enter patient temperature and at least one BGA value',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ]),
        ),

      // ── Results ────────────────────────────────────────────────────────────
      if (anyResult) ...[
        const SectionHeader('Corrected values at patient temperature'),

        if (hasCorrPaO2) ...[
          ResultCard(
            label: 'PaO\u2082 (T-corrected)',
            unit: 'mmHg',
            value: _model.corrPaO2!,
            decimals: 1,
            rangeHint: 'PO\u2082(T) = PO\u2082(37) \u00d7 e^(f\u1d40\u00d7\u0394T)  ·  Severinghaus 1979, Eq. 3',
          ),
          if (_model.fTPercent != null)
            _formulaHintCard(
              'Temperaturkoeffizient f\u1d40 = ${_model.fTPercent!.toStringAsFixed(2)} %/°C',
              'Variiert: ~7.4 %/°C bei niedriger, ~1.3 %/°C bei hoher Sättigung',
            ),
        ],

        if (hasCorrCO2)
          ResultCard(
            label: 'PaCO\u2082 (T-corrected)',
            unit: 'mmHg',
            value: _model.corrPaCO2!,
            decimals: 1,
            rangeHint: 'PCO\u2082(T) = PCO\u2082(37) \u00d7 10^(0.0185\u00d7\u0394T)  ·  Bradley & Severinghaus 1956',
          ),

        if (hasCorrPH)
          ResultCard(
            label: 'pH (T-corrected)',
            unit: '',
            value: _model.corrPH!,
            decimals: 3,
            rangeHint: 'pH(T) = pH(37) \u2212 0.0147 \u00d7 \u0394T  ·  Severinghaus & Bradley 1956',
          ),

        if (_model.hco3 != null)
          ResultCard(
            label: 'HCO\u2083\u207b (Henderson-Hasselbalch)',
            unit: 'mmol/L',
            value: _model.hco3!,
            decimals: 1,
            rangeHint: 'HCO\u2083\u207b = 0.0307 \u00d7 PCO\u2082 \u00d7 10^(pH\u22126.105)  ·  Severinghaus 1966',
          ),

        if (_model.satFromPaO2 != null)
          ResultCard(
            label: 'SaO\u2082 (O\u2082-Dissoziationskurve)',
            unit: '%',
            value: _model.satFromPaO2!,
            decimals: 1,
            rangeHint: 'S = (23400\u00d7(PO\u2082\u00b3+150\u00d7PO\u2082)\u207b\u00b9 + 1)\u207b\u00b9  ·  Severinghaus 1979, Eq. 1',
          ),

        // Clinical thumb rules
        const SectionHeader('Clinical thumb rules (per 1 °C below 37 °C)'),
        _thumbRuleTable(),
      ],
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
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            _hCell('Parameter', flex: 2),
            _hCell('Rule',      flex: 3),
            _hCell('\u0394 total', flex: 2),
            _hCell('Unit',      flex: 2),
          ]),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final isLast = i == rows.length - 1;
          final isDelta = dT != null && r[2] != '–';
          return Container(
            decoration: BoxDecoration(
              color: i.isOdd ? const Color(0xFF222222) : const Color(0xFF1A1A1A),
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(children: [
              _cell(r[0], flex: 2, color: kGold, bold: true),
              _cell(r[1], flex: 3),
              _cell(r[2], flex: 2,
                  color: isDelta ? Colors.white : Colors.white38,
                  bold: isDelta),
              _cell(r[3], flex: 2, color: Colors.white54),
            ]),
          );
        }),
        // Source footnote
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: const Text(
            'StatPearls NBK557769  ·  Deranged Physiology',
            style: TextStyle(color: Colors.white24, fontSize: 10),
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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        const Icon(Icons.functions, color: Colors.white24, size: 13),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(main, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(sub,  style: const TextStyle(color: Colors.white24, fontSize: 10)),
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

  Widget _cell(String text, {int flex = 1, Color color = Colors.white, bool bold = false}) =>
      Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(text,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13)),
        ),
      );
}
