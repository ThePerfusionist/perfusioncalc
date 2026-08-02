import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

class UltrafiltrationScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const UltrafiltrationScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<UltrafiltrationScreen> createState() => _UltrafiltrationScreenState();
}

/// Which concentration marker the current/target pair below is expressed
/// in. Mirrors the CO/CI toggle on the O2 delivery tab: only one pair
/// (Hct or Hb) is ever populated at a time, the other is cleared on switch.
enum _UfMetric { hct, hb }

class _UltrafiltrationScreenState extends State<UltrafiltrationScreen> {
  PatientData get patientData => widget.patientData;

  // Derive the initial toggle position from whatever data is already
  // present (e.g. after a tab switch), instead of always defaulting to
  // Hct - a bit more robust than a blind default.
  late _UfMetric _metric = (patientData.ufCurrentHb != null || patientData.ufTargetHb != null)
      ? _UfMetric.hb
      : _UfMetric.hct;

  /// Local rebuild: updates only this screen, not the whole MainScreen.
  /// The (no-op) parent callback is then notified.
  void onChanged() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  void _switchMetric(_UfMetric metric) {
    if (metric == _metric) return;
    setState(() {
      _metric = metric;
      // Clear the other pair so the two never get mixed in the underlying
      // calculation (which only ever reads one populated pair - see
      // PatientData._ufMetricPair).
      if (metric == _UfMetric.hct) {
        patientData.ufCurrentHb = null;
        patientData.ufTargetHb = null;
      } else {
        patientData.ufCurrentHct = null;
        patientData.ufTargetHct = null;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isHct = _metric == _UfMetric.hct;

    // Helper: collect the missing required inputs for the result cards.
    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final hVolume = (v: patientData.ufCurrentVolume, label: t('uf_current_volume'));
    final hCurrent = isHct
        ? (v: patientData.ufCurrentHct, label: t('uf_current_hct'))
        : (v: patientData.ufCurrentHb,  label: t('uf_current_hb'));
    final hTarget = isHct
        ? (v: patientData.ufTargetHct, label: t('uf_target_hct'))
        : (v: patientData.ufTargetHb,  label: t('uf_target_hb'));

    // Both values entered, but target not achievable by filtration alone
    // (UF can only concentrate blood, never dilute it) - checked generically
    // for whichever metric is currently active.
    final curVal = isHct ? patientData.ufCurrentHct : patientData.ufCurrentHb;
    final tgtVal = isHct ? patientData.ufTargetHct : patientData.ufTargetHb;
    final showTargetWarning = curVal != null && tgtVal != null && tgtVal <= curVal;

    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),
        InputCard(label: t('uf_current_volume'), unit: 'ml', value: patientData.ufCurrentVolume,
            range: Ranges.circulatingVolume,
            step: 50, onChanged: (v) { patientData.ufCurrentVolume = v; onChanged(); }),

        // ── Metric toggle (Hct / Hb) ────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kCardColor, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kGold.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('uf_metric_label'), style: TextStyle(color: kText, fontSize: 14)),
            Container(
              decoration: BoxDecoration(color: kTableHeaderBg, borderRadius: const BorderRadius.all(Radius.circular(20))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _toggleBtn('Hct', _UfMetric.hct),
                _toggleBtn('Hb',  _UfMetric.hb),
              ]),
            ),
          ]),
        ),

        InputCard(
          label: isHct ? t('uf_current_hct') : t('uf_current_hb'),
          unit: isHct ? '%' : 'g/dl',
          value: isHct ? patientData.ufCurrentHct : patientData.ufCurrentHb,
          range: isHct ? Ranges.hct : Ranges.hb,
          onChanged: (v) {
            if (isHct) { patientData.ufCurrentHct = v; } else { patientData.ufCurrentHb = v; }
            onChanged();
          },
        ),
        InputCard(
          label: isHct ? t('uf_target_hct') : t('uf_target_hb'),
          unit: isHct ? '%' : 'g/dl',
          value: isHct ? patientData.ufTargetHct : patientData.ufTargetHb,
          range: isHct ? Ranges.hct : Ranges.hb,
          onChanged: (v) {
            if (isHct) { patientData.ufTargetHct = v; } else { patientData.ufTargetHb = v; }
            onChanged();
          },
        ),

        if (showTargetWarning)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFA726), size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(
                t('uf_warning_not_higher'),
                style: TextStyle(color: kTextSecondary, fontSize: 12),
              )),
            ]),
          ),

        SectionHeader(t('uf_section_result')),
        ResultCard(label: t('uf_volume_remove'), unit: 'ml', value: patientData.ufVolumeToRemove,
            decimals: 0,
            missingInputs: missing([hVolume, hCurrent, hTarget])),
        ResultCard(label: t('uf_final_volume'), unit: 'ml', value: patientData.ufFinalVolume,
            decimals: 0,
            missingInputs: missing([hVolume, hCurrent, hTarget])),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: kTextGhost, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(
              t('uf_principle_note'),
              style: TextStyle(color: kTextFaint, fontSize: 11.5),
            )),
          ]),
        ),

        const SizedBox(height: 8),
        PdfExportButton(
          filename: 'ultrafiltration',
          tabTitleKey: 'tab_ultrafiltration',
          buildSections: () => buildUltrafiltrationPdfSections(patientData),
        ),
        SourceButton(refs: [
          AppSources.klineberg1984,
          AppSources.hensley2024,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _toggleBtn(String label, _UfMetric metric) {
    final active = _metric == metric;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _switchMetric(metric),
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
}

/// Non-null, sobald ein vollstaendiges Wertepaar vorliegt - Hkt ODER Hb.
/// Der Rueckgabewert selbst ist bedeutungslos, nur null / nicht-null zaehlt.
Object? _ufPairPresent(PatientData pd) {
  final hctPair = pd.ufCurrentHct != null && pd.ufTargetHct != null;
  final hbPair = pd.ufCurrentHb != null && pd.ufTargetHb != null;
  return (hctPair || hbPair) ? true : null;
}

// ── PDF sections (extracted, for the single-tab export and the combined report) ─
List<PdfSection> buildUltrafiltrationPdfSections(PatientData pd) => [
  PdfSection(title: t('pdf_inputs'), rows: [
    PdfRow.numeric(label: t('uf_current_volume'), value: pd.ufCurrentVolume, unit: 'ml', decimals: 0),
    PdfRow.numeric(label: t('uf_current_hct'),    value: pd.ufCurrentHct,    unit: '%'),
    PdfRow.numeric(label: t('uf_target_hct'),     value: pd.ufTargetHct,     unit: '%'),
    PdfRow.numeric(label: t('uf_current_hb'),     value: pd.ufCurrentHb,     unit: 'g/dl'),
    PdfRow.numeric(label: t('uf_target_hb'),      value: pd.ufTargetHb,      unit: 'g/dl'),
  ]),
  // 0 ml ist hier ein Ergebnis: "das Ziel ist durch Filtration nicht
  // erreichbar bzw. schon erreicht". Der Bildschirm zeigte 0, das PDF "—".
  // Welches Wertepaar zaehlt, haengt am gewaehlten Modus (Hkt oder Hb) -
  // deshalb wird geprueft, ob EINES der beiden Paare vollstaendig ist.
  PdfSection(title: t('pdf_results'), rows: [
    PdfRow.numeric(label: t('uf_volume_remove'),
        value: resultIf([pd.ufCurrentVolume, _ufPairPresent(pd)], pd.ufVolumeToRemove),
        unit: 'ml', decimals: 0, zeroIsValid: true),
    PdfRow.numeric(label: t('uf_final_volume'),
        value: resultIf([pd.ufCurrentVolume, _ufPairPresent(pd)], pd.ufFinalVolume),
        unit: 'ml', decimals: 0, zeroIsValid: true),
  ]),
];
