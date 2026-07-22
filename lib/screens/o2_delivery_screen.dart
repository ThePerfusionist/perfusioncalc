import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

class O2DeliveryScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const O2DeliveryScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<O2DeliveryScreen> createState() => _O2DeliveryScreenState();
}

enum _CoMode { co, ci }

class _O2DeliveryScreenState extends State<O2DeliveryScreen> {
  _CoMode _mode = _CoMode.co;
  PatientData get pd => widget.patientData;

  /// Local rebuild of this screen instead of a global MainScreen rebuild.
  void _recalc() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  void _switchMode(_CoMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _CoMode.co) { pd.cardiacIndex = null; }
      else { pd.hzv = null; }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        _CoCiCard(
          mode: _mode, coValue: pd.hzv, ciValue: pd.cardiacIndex, bsaValue: pd.kof,
          onModeChanged: _switchMode,
          onCoChanged: (v) { pd.hzv = v; pd.cardiacIndex = null; _recalc(); },
          onCiChanged: (v) { pd.cardiacIndex = v; pd.hzv = null; _recalc(); },
        ),
        InputCard(label: t('o2_bsa'), unit: 'm\u00b2', value: pd.kof, step: 0.01,
            range: Ranges.bsa,
            onChanged: (v) { pd.kof = v; _recalc(); }),
        InputCard(label: 'PaO\u2082', unit: 'mmHg', value: pd.paO2,
            range: Ranges.paO2,
            onChanged: (v) { pd.paO2 = v; _recalc(); }),
        InputCard(label: 'SaO\u2082', unit: '%', value: pd.saO2,
            range: Ranges.saO2,
            onChanged: (v) { pd.saO2 = v; _recalc(); }),
        InputCard(label: t('o2_art_hb'), unit: 'g/dl', value: pd.artHb,
            range: Ranges.hb,
            onChanged: (v) { pd.artHb = v; _recalc(); }),
        InputCard(label: 'PvO\u2082', unit: 'mmHg', value: pd.pvO2,
            range: Ranges.pvO2,
            onChanged: (v) { pd.pvO2 = v; _recalc(); }),
        InputCard(label: 'SvO\u2082', unit: '%', value: pd.svO2,
            range: Ranges.svO2,
            onChanged: (v) { pd.svO2 = v; _recalc(); }),
        InputCard(label: t('o2_ven_hb'), unit: 'g/dl', value: pd.venHb,
            range: Ranges.hb,
            onChanged: (v) { pd.venHb = v; _recalc(); }),
        // ── Calculated results ────────────────────────────────────────────
        // CO/CI handling: cardiacIndexEffective is >0 if the user entered
        // either CO+BSA or CI directly (see _CoCiCard).
        Builder(builder: (_) {
          // Shorthand helpers for missing required fields
          List<String> missing(List<({Object? v, String label})> fields) =>
              fields.where((f) => f.v == null).map((f) => f.label).toList();

          // For CO-dependent results: CO directly OR CI+BSA is sufficient
          List<String> coDerivedMissing() {
            if (pd.hzv != null) return [];
            if (pd.cardiacIndex != null && pd.kof != null) return [];
            final out = <String>[];
            if (pd.hzv == null && pd.cardiacIndex == null) out.add(t('o2_co_label'));
            if (pd.cardiacIndex != null && pd.kof == null) out.add(t('o2_bsa'));
            return out;
          }
          // For CI-dependent results: CI directly OR CO+BSA is sufficient
          List<String> ciDerivedMissing() {
            if (pd.cardiacIndex != null) return [];
            if (pd.hzv != null && pd.kof != null) return [];
            final out = <String>[];
            if (pd.hzv == null && pd.cardiacIndex == null) out.add(t('o2_ci_label'));
            if (pd.hzv != null && pd.kof == null) out.add(t('o2_bsa'));
            return out;
          }

          final hPaO2  = (v: pd.paO2,  label: 'PaO\u2082');
          final hSaO2  = (v: pd.saO2,  label: 'SaO\u2082');
          final hArtHb = (v: pd.artHb, label: t('o2_art_hb'));
          final hPvO2  = (v: pd.pvO2,  label: 'PvO\u2082');
          final hSvO2  = (v: pd.svO2,  label: 'SvO\u2082');
          final hVenHb = (v: pd.venHb, label: t('o2_ven_hb'));
          final hBsa   = (v: pd.kof,   label: t('o2_bsa'));

          final caO2Inputs = [hArtHb, hSaO2, hPaO2];
          final cvO2Inputs = [hVenHb, hSvO2, hPvO2];
          final cavInputs  = [...caO2Inputs, ...cvO2Inputs];

          return Column(children: [
            ResultCard(label: 'CaO\u2082',    unit: 'ml/dl',          value: pd.caO2,
                rangeHint: '(18-20 ml O\u2082/dl)',
                missingInputs: missing(caO2Inputs)),
            ResultCard(label: 'CvO\u2082',    unit: 'ml/dl',          value: pd.cvO2,
                rangeHint: '(14-15 ml O\u2082/dl)',
                missingInputs: missing(cvO2Inputs)),
            ResultCard(label: 'Ca-vDO\u2082', unit: 'ml/dl',          value: pd.cavDO2,
                rangeHint: '(4-6 ml/dl)',
                missingInputs: missing(cavInputs)),
            ResultCard(label: 'DO\u2082',     unit: 'ml/min',         value: pd.do2,
                missingInputs: [...missing(caO2Inputs), ...coDerivedMissing()]),
            ResultCard(label: 'DO\u2082i',    unit: 'ml/min/m\u00b2', value: pd.do2i,
                rangeHint: '(>272 ml/min/m\u00b2)',
                warnBelow: 272,
                warnMessage: t('do2i_gdp_warning'),
                missingInputs: [...missing(caO2Inputs), ...ciDerivedMissing()]),
            ResultCard(label: 'VO\u2082',     unit: 'ml/min',         value: pd.vo2,
                missingInputs: [...missing(cavInputs), ...coDerivedMissing()]),
            ResultCard(label: 'VO\u2082i',    unit: 'ml/min/m\u00b2', value: pd.vo2i,
                rangeHint: '(120-160 ml/min/m\u00b2)',
                missingInputs: [...missing(cavInputs), ...ciDerivedMissing()]),
            ResultCard(label: 'O\u2082-ER',   unit: '%',              value: pd.o2er,
                rangeHint: '(22-35%)',
                missingInputs: [...missing(cavInputs), ...coDerivedMissing()]),
            ResultCard(label: t('o2_min_co'), unit: 'L/min',
                value: pd.minCardiacOutput,
                rangeHint: t('o2_min_at'),
                missingInputs: missing([hArtHb, hSaO2, hPaO2, hBsa])),
            ResultCard(label: t('o2_min_hb'), unit: 'g/dl',
                value: pd.minHb,
                rangeHint: t('o2_min_at'),
                missingInputs: [...missing([hSaO2, hPaO2, hBsa]), ...coDerivedMissing()]),
          ]);
        }),
        const SizedBox(height: 8),
        // Chart button
        GestureDetector(
          onTap: () => _showChartDialog(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            width: double.infinity,
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(t('o2_chart'), style:  TextStyle(color: kText, fontSize: 15)),
              const SizedBox(width: 8),
               Icon(Icons.bar_chart, color: kTextSecondary, size: 20),
            ]),
          ),
        ),
        PdfExportButton(
          filename: 'o2_delivery',
          tabTitleKey: 'tab_o2',
          buildSections: () => buildO2PdfSections(pd),
        ),
        SourceButton(refs: [
          AppSources.deSomer,
          AppSources.newland2019,
          AppSources.newland2017,
          AppSources.ranucci2018,
          AppSources.ranucci2005,
          AppSources.gao2023,
          AppSources.huefner,
          AppSources.dijkhuizen1977,
          AppSources.eactsKunst2024,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _showChartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(t('o2_chart_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image.asset('assets/o2_chart.png')),
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(t('close'), style: const TextStyle(color: Colors.redAccent))),
        ]),
      ),
    );
  }
}

// ── Merged CO/CI card ─────────────────────────────────────────────────────────
class _CoCiCard extends StatefulWidget {
  final _CoMode mode;
  final double? coValue, ciValue, bsaValue;
  final ValueChanged<_CoMode> onModeChanged;
  final ValueChanged<double?> onCoChanged, onCiChanged;

  const _CoCiCard({required this.mode, required this.coValue, required this.ciValue,
    required this.bsaValue, required this.onModeChanged, required this.onCoChanged, required this.onCiChanged});

  @override
  State<_CoCiCard> createState() => _CoCiCardState();
}

class _CoCiCardState extends State<_CoCiCard> {
  late TextEditingController _ctrl;
  bool _editing = false;

  double? get _val => widget.mode == _CoMode.co ? widget.coValue : widget.ciValue;
  ValueChanged<double?> get _cb => widget.mode == _CoMode.co ? widget.onCoChanged : widget.onCiChanged;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: _fmt(_val)); }

  @override
  void didUpdateWidget(_CoCiCard old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      final t = _fmt(_val);
      if (_ctrl.text != t) { _ctrl.text = t; _ctrl.selection = TextSelection.collapsed(offset: t.length); }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _fmt(double? v) {
    if (v == null) return '';
    String s = v.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _inc() => _cb(double.parse(((_val ?? 0) + 0.1).toStringAsFixed(4)));
  void _dec() => _cb(double.parse(((_val ?? 0) - 0.1).toStringAsFixed(4)));

  @override
  Widget build(BuildContext context) {
    final isCo = widget.mode == _CoMode.co;
    String? hint;
    if (isCo && widget.coValue != null && widget.bsaValue != null && widget.bsaValue! > 0) {
      hint = 'CI = ${(widget.coValue! / widget.bsaValue!).toStringAsFixed(2)} l/min/m\u00b2';
    } else if (!isCo && widget.ciValue != null && widget.bsaValue != null && widget.bsaValue! > 0) {
      hint = 'CO = ${(widget.ciValue! * widget.bsaValue!).toStringAsFixed(2)} l/min';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCardColor, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isCo ? t('o2_co_label') : t('o2_ci_label'),
                style:  TextStyle(color: kText, fontSize: 14)),
            Container(
              decoration:  BoxDecoration(color: kTableHeaderBg, borderRadius: BorderRadius.all(Radius.circular(20))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _toggleBtn('CO', _CoMode.co), _toggleBtn('CI', _CoMode.ci),
              ]),
            ),
          ]),
          Text(isCo ? 'l/min' : 'l/min/m\u00b2', style:  TextStyle(color: kTextMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Row(children: [
            _btn(Icons.remove, _dec, '${t('a11y_decrease')}: ${isCo ? t('o2_co_label') : t('o2_ci_label')}'),
            Expanded(child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style:  TextStyle(color: kTextSecondary, fontSize: 22),
              decoration: InputDecoration(border: InputBorder.none, hintText: t('o2_enter_value'),
                  hintStyle:  TextStyle(color: kTextGhost2, fontSize: 18)),
              onTap: () => setState(() => _editing = true),
              onChanged: (s) => _cb(double.tryParse(s.replaceAll(',', '.'))),
              onEditingComplete: () { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
              onTapOutside: (_) { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
            )),
            _btn(Icons.add, _inc, '${t('a11y_increase')}: ${isCo ? t('o2_co_label') : t('o2_ci_label')}'),
          ]),
          if (hint != null) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(hint, style: TextStyle(color: kGold.withValues(alpha: 0.7), fontSize: 11)),
          ),
        ]),
      ),
    );
  }

  Widget _toggleBtn(String label, _CoMode mode) {
    final active = widget.mode == mode;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () { if (!active) { setState(() => _ctrl.text = ''); widget.onModeChanged(mode); } },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: active ? kGold : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(color: active ? Colors.black : kTextMuted,
              fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, String semanticLabel) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(width: 36, height: 36,
          decoration:  BoxDecoration(color: kBtnGrey, shape: BoxShape.circle),
          child: Icon(icon, color: kText, size: 20)),
    ),
  );
}

// ── PDF sections (extracted, for the single-tab export and the combined report) ─
List<PdfSection> buildO2PdfSections(PatientData pd) => [
  PdfSection(title: t('pdf_inputs'), rows: [
    PdfRow.numeric(label: t('o2_bsa'),    value: pd.kof,    unit: 'm²'),
    PdfRow.numeric(label: 'PaO\u2082',    value: pd.paO2,   unit: 'mmHg'),
    PdfRow.numeric(label: 'SaO\u2082',    value: pd.saO2,   unit: '%'),
    PdfRow.numeric(label: t('o2_art_hb'), value: pd.artHb,  unit: 'g/dl'),
    PdfRow.numeric(label: 'PvO\u2082',    value: pd.pvO2,   unit: 'mmHg'),
    PdfRow.numeric(label: 'SvO\u2082',    value: pd.svO2,   unit: '%'),
    PdfRow.numeric(label: t('o2_ven_hb'), value: pd.venHb,  unit: 'g/dl'),
    PdfRow.numeric(label: t('o2_co_label'), value: pd.hzv,  unit: 'l/min'),
    PdfRow.numeric(label: t('o2_ci_label'), value: pd.cardiacIndex, unit: 'l/min/m²'),
  ]),
  PdfSection(title: t('pdf_results'), rows: [
    PdfRow.numeric(label: 'CaO\u2082',     value: pd.caO2,   unit: 'ml/dl'),
    PdfRow.numeric(label: 'CvO\u2082',     value: pd.cvO2,   unit: 'ml/dl'),
    PdfRow.numeric(label: 'Ca-vDO\u2082',  value: pd.cavDO2, unit: 'ml/dl'),
    PdfRow.numeric(label: 'DO\u2082',      value: pd.do2,    unit: 'ml/min',         decimals: 0),
    PdfRow.numeric(label: 'DO\u2082i',     value: pd.do2i,   unit: 'ml/min/m²',      decimals: 0),
    PdfRow.numeric(label: 'VO\u2082',      value: pd.vo2,    unit: 'ml/min',         decimals: 0),
    PdfRow.numeric(label: 'VO\u2082i',     value: pd.vo2i,   unit: 'ml/min/m²',      decimals: 0),
    PdfRow.numeric(label: 'O\u2082-ER',    value: pd.o2er,   unit: '%'),
    PdfRow.numeric(label: t('o2_min_co'),  value: pd.minCardiacOutput, unit: 'l/min'),
    PdfRow.numeric(label: t('o2_min_hb'),  value: pd.minHb,  unit: 'g/dl'),
  ]),
];
