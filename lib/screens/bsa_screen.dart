import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

const _kCiKey = 'bsa_cardiac_index';

class BSAScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const BSAScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<BSAScreen> createState() => _BSAScreenState();
}

class _BSAScreenState extends State<BSAScreen> {
  bool _loaded = false;

  /// Local rebuild of this screen instead of a global MainScreen rebuild.
  void _recalc() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  @override
  void initState() { super.initState(); _loadCI(); }

  Future<void> _loadCI() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(_kCiKey) ?? 2.4;
    // Validate against corrupted / tampered preference values
    final safe = (raw.isNaN || raw.isInfinite || raw <= 0 || raw > 10) ? 2.4 : raw;
    setState(() {
      widget.patientData.bsaCardiacIndex = safe;
      _loaded = true;
    });
    // If the stored value was invalid, overwrite with the safe default
    if (safe != raw) await prefs.setDouble(_kCiKey, safe);
    widget.onChanged();
  }

  Future<void> _saveCI(double v) async {
    // Only persist sensible values; reject NaN/Infinity/out-of-range
    if (v.isNaN || v.isInfinite || v <= 0 || v > 10) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kCiKey, v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final pd = widget.patientData;
    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),
        InputCard(label: t('bsa_body_height'), unit: 'cm', value: pd.height,
            range: Ranges.height,
            onChanged: (v) { pd.height = v; _recalc(); }),
        InputCard(label: t('bsa_body_weight'), unit: 'kg', value: pd.weight,
            range: Ranges.weight,
            onChanged: (v) { pd.weight = v; _recalc(); }),
        InputCard(label: t('bsa_current_hb'), unit: 'g/dl', value: pd.currentHb,
            range: Ranges.hb,
            onChanged: (v) { pd.currentHb = v; _recalc(); }),
        InputCard(label: t('bsa_current_hct'), unit: '%', value: pd.currentHct,
            range: Ranges.hct,
            onChanged: (v) { pd.currentHct = v; _recalc(); }),
        InputCard(label: t('bsa_priming_volume'), unit: 'ml', value: pd.primingVolume,
            range: Ranges.primingVolume,
            step: 1, onChanged: (v) { pd.primingVolume = v; _recalc(); }),
        _CIInputCard(
          value: pd.bsaCardiacIndex,
          onChanged: (v) {
            if (v != null && v > 0) {
              pd.bsaCardiacIndex = v;
              pd.bsaCardiacIndexTouched = true;
              _saveCI(v);
              _recalc();
            }
          },
        ),
        // ── Calculated results ────────────────────────────────────────────
        // Helper lists: collect the inputs each formula needs.
        // If even one is missing, "—" is shown instead of a number.
        Builder(builder: (_) {
          List<String> missing(List<({Object? v, String label})> fields) =>
              fields.where((f) => f.v == null).map((f) => f.label).toList();

          final hHeight = (v: pd.height, label: t('bsa_body_height'));
          final hWeight = (v: pd.weight, label: t('bsa_body_weight'));
          final hHb     = (v: pd.currentHb, label: t('bsa_current_hb'));
          final hHct    = (v: pd.currentHct, label: t('bsa_current_hct'));
          final hPrim   = (v: pd.primingVolume, label: t('bsa_priming_volume'));

          return Column(children: [
            ResultCard(
              label: t('bsa_result_dubois'),
              unit: 'm\u00b2',
              value: pd.bsa,
              missingInputs: missing([hHeight, hWeight]),
            ),
            ResultCard(
              label: '${t('bsa_result_co')} (CI ${pd.bsaCardiacIndex.toStringAsFixed(1)})',
              unit: 'l/min',
              value: pd.cardiacOutput,
              missingInputs: missing([hHeight, hWeight]),
            ),
            // rangeHint marks these as a weight-only approximation rather
            // than a primary-literature formula - see the comment on
            // PatientData.bloodVolumeMale.
            ResultCard(
              label: t('bsa_result_bv_male'),
              unit: 'l',
              value: pd.bloodVolumeMale,
              rangeHint: t('bsa_bv_approx'),
              missingInputs: missing([hWeight]),
            ),
            ResultCard(
              label: t('bsa_result_bv_female'),
              unit: 'l',
              value: pd.bloodVolumeFemale,
              rangeHint: t('bsa_bv_approx'),
              missingInputs: missing([hWeight]),
            ),
            SectionHeader(t('bsa_section_expected')),
            ResultCard(
              label: t('bsa_expected_hb_m'),
              unit: 'g/dl',
              value: pd.expectedHbMale,
              missingInputs: missing([hWeight, hHb, hPrim]),
            ),
            ResultCard(
              label: t('bsa_expected_hb_f'),
              unit: 'g/dl',
              value: pd.expectedHbFemale,
              missingInputs: missing([hWeight, hHb, hPrim]),
            ),
            ResultCard(
              label: t('bsa_expected_hct_m'),
              unit: '%',
              value: pd.expectedHctMale,
              missingInputs: missing([hWeight, hHct, hPrim]),
            ),
            ResultCard(
              label: t('bsa_expected_hct_f'),
              unit: '%',
              value: pd.expectedHctFemale,
              missingInputs: missing([hWeight, hHct, hPrim]),
            ),
          ]);
        }),
        const SizedBox(height: 8),
        PdfExportButton(
          filename: 'bsa',
          tabTitleKey: 'tab_bsa',
          buildSections: () => buildBsaPdfSections(pd),
        ),
        SourceButton(refs: [
          AppSources.dubois,
          AppSources.silbernagl,
          AppSources.nadler,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _CIInputCard extends StatefulWidget {
  final double value;
  final ValueChanged<double?> onChanged;
  const _CIInputCard({required this.value, required this.onChanged});
  @override
  State<_CIInputCard> createState() => _CIInputCardState();
}

class _CIInputCardState extends State<_CIInputCard> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: formatFieldNumber(widget.value)); }

  @override
  void didUpdateWidget(_CIInputCard old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      final t = formatFieldNumber(widget.value);
      if (_ctrl.text != t) { _ctrl.text = t; _ctrl.selection = TextSelection.collapsed(offset: t.length); }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _inc() => widget.onChanged(double.parse((widget.value + 0.1).toStringAsFixed(4)));
  void _dec() => widget.onChanged(double.parse((widget.value - 0.1).toStringAsFixed(4)));

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withValues(alpha: 0.25), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text(t('bsa_cardiac_index'), style:  TextStyle(color: kText, fontSize: 14)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(t('bsa_saved'), style: const TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
             Text('l/min/m\u00b2', style: TextStyle(color: kTextSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _btn(Icons.remove, _dec, '${t('a11y_decrease')}: ${t('bsa_cardiac_index')}'),
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style:  TextStyle(color: kTextSecondary, fontSize: 22),
                decoration: const InputDecoration(border: InputBorder.none),
                onTap: () => setState(() => _editing = true),
                onChanged: (s) => widget.onChanged(double.tryParse(s.replaceAll(',', '.'))),
                onEditingComplete: () { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
                onTapOutside: (_) { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
              ),
            ),
            _btn(Icons.add, _inc, '${t('a11y_increase')}: ${t('bsa_cardiac_index')}'),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t('bsa_saved_hint'),
                style:  TextStyle(color: kTextFaint, fontSize: 10)),
          ),
        ]),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, String semanticLabel) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration:  BoxDecoration(color: kBtnGrey, shape: BoxShape.circle),
        child: Icon(icon, color: kText, size: 20),
      ),
    ),
  );
}

// ── PDF sections (extracted so both the single-tab export and the
// combined report (see main.dart) use the same logic) ──────────────────────
List<PdfSection> buildBsaPdfSections(PatientData pd) => [
  PdfSection(title: t('pdf_inputs'), rows: [
    PdfRow.numeric(label: t('bsa_body_height'),     value: pd.height,         unit: 'cm'),
    PdfRow.numeric(label: t('bsa_body_weight'),     value: pd.weight,         unit: 'kg'),
    PdfRow.numeric(label: t('bsa_current_hb'),      value: pd.currentHb,      unit: 'g/dl'),
    PdfRow.numeric(label: t('bsa_current_hct'),     value: pd.currentHct,     unit: '%'),
    PdfRow.numeric(label: t('bsa_priming_volume'),  value: pd.primingVolume,  unit: 'ml', decimals: 0),
    PdfRow.numeric(label: t('bsa_cardiac_index'),
        value: pd.bsaCardiacIndexTouched ? pd.bsaCardiacIndex : null,
        unit: 'l/min/m²', decimals: 1),
  ]),
  PdfSection(title: t('pdf_results'), rows: [
    PdfRow.numeric(label: t('bsa_result_dubois'),     value: pd.bsa,             unit: 'm²'),
    PdfRow.numeric(label: t('bsa_result_co'),         value: pd.cardiacOutput,   unit: 'l/min'),
    PdfRow.numeric(label: t('bsa_result_bv_male'),    value: pd.bloodVolumeMale,   unit: 'l'),
    PdfRow.numeric(label: t('bsa_result_bv_female'),  value: pd.bloodVolumeFemale, unit: 'l'),
    PdfRow.numeric(label: t('bsa_expected_hb_m'),     value: pd.expectedHbMale,    unit: 'g/dl'),
    PdfRow.numeric(label: t('bsa_expected_hb_f'),     value: pd.expectedHbFemale,  unit: 'g/dl'),
    PdfRow.numeric(label: t('bsa_expected_hct_m'),    value: pd.expectedHctMale,   unit: '%'),
    PdfRow.numeric(label: t('bsa_expected_hct_f'),    value: pd.expectedHctFemale, unit: '%'),
  ]),
];
