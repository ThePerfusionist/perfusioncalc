import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

// Molar masses for the mmol/ml <-> % (w/v) concentration toggles on the
// Calafiore syringe fields below.
// %(w/v) = g per 100 ml; mmol/ml = (percent x 10) / molar mass (g/mol).
// KCl: K 39.098 + Cl 35.453 = 74.551 g/mol.
// Verified: KCl 14.9% -> 1.999 mmol/ml (matches the institutional 2 mmol/ml
// reference exactly).
const double _kKclMolarMass = 74.55;
// MgSO4 . 7H2O (magnesium sulfate heptahydrate). The institutional
// ampoule is labeled 500 mg/ml, i.e. 20 mmol Mg2+ per 10 ml ampoule
// (~2.0 mmol/ml, confirmed by direct inspection of the ampoule) - this
// corresponds to ~50% (w/v). 246.47 g/mol.
const double _kMgso4MolarMass = 246.47;

const String _kUnitMmolPerMl = 'mmol/ml';
const String _kUnitPercent = '%';

double _mmolPerMlToPercent(double mmolPerMl, double molarMass) => mmolPerMl * molarMass / 10;
double _percentToMmolPerMl(double percent, double molarMass) => percent * 10 / molarMass;

class CardioplegiaScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const CardioplegiaScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<CardioplegiaScreen> createState() => _CardioplegiaScreenState();
}

/// Which cardioplegia protocol is currently shown.
///
/// Buckberg and del Nido are intentionally NOT offered in the protocol
/// picker right now (see _kVisibleProtocols): they are not used at the
/// institution this app is maintained for, so showing them would only
/// invite mis-selection. Their enum values, calculation code
/// (PatientData.buckberg*/delNido*), tests, and UI section are all kept
/// intact so the protocols can be re-enabled by simply adding them back to
/// _kVisibleProtocols - nothing has to be rewritten.
enum _CardioProtocol { buckberg, delNido, calafiore, bretschneider }

const List<_CardioProtocol> _kVisibleProtocols = [
  _CardioProtocol.calafiore,
  _CardioProtocol.bretschneider,
];

String _protocolLabel(_CardioProtocol p) => switch (p) {
      _CardioProtocol.buckberg => 'Buckberg',
      _CardioProtocol.delNido => 'del Nido',
      _CardioProtocol.calafiore => 'Calafiore',
      _CardioProtocol.bretschneider => 'Bretschneider',
    };

class _CardioplegiaScreenState extends State<CardioplegiaScreen> {
  PatientData get patientData => widget.patientData;
  _CardioProtocol _protocol = _kVisibleProtocols.first;

  // Unit selection for the two Calafiore syringe concentration fields.
  // Purely a display/input convenience: the canonical stored value stays
  // mmol/ml (PatientData.cardioplegiaCalafioreKclConc/MgConc) regardless of
  // which unit is currently shown - switching converts and preserves the
  // value exactly (% <-> mmol/ml is a lossless, unambiguous conversion via
  // a fixed molar mass, so there's no reason to clear the field on switch).
  String _kclUnit = _kUnitMmolPerMl;
  String _mgUnit = _kUnitMmolPerMl;

  /// 1-second ticker that only redraws the elapsed-time readout. It is
  /// started/stopped on demand so no timer runs while no delivery has been
  /// recorded - and it is always cancelled in dispose(), otherwise it would
  /// keep firing setState on a disposed State.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final needsTicker = patientData.cardioplegiaLastDoseAt != null;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  /// Local rebuild: updates only this screen, not the whole MainScreen.
  /// The (no-op) parent callback is then notified.
  void onChanged() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  void _switchProtocol(_CardioProtocol protocol) {
    if (protocol == _protocol) return;
    setState(() => _protocol = protocol);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),

        // ── Protocol picker (only the protocols in _kVisibleProtocols) ─────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kCardColor, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kGold.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('cardio_protocol_label'), style: TextStyle(color: kText, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: kTableHeaderBg, borderRadius: const BorderRadius.all(Radius.circular(20))),
              child: Row(children: [
                for (final p in _kVisibleProtocols)
                  Expanded(child: _toggleBtn(_protocolLabel(p), p)),
              ]),
            ),
          ]),
        ),

        switch (_protocol) {
          _CardioProtocol.calafiore => _buildCalafioreSection(),
          _CardioProtocol.bretschneider => _buildBretschneiderSection(),
          _ => _buildWeightBasedSection(),
        },

        const SizedBox(height: 8),
        PdfExportButton(
          filename: 'cardioplegia',
          tabTitleKey: 'tab_cardioplegia',
          buildSections: () => buildCardioplegiaPdfSections(patientData),
        ),
        SourceButton(refs: _sourcesForProtocol()),
        const SizedBox(height: 16),
      ]),
    );
  }

  /// Only cite what's actually on screen - listing every protocol's sources
  /// under a single protocol view would make it unclear which reference
  /// backs the numbers the user is looking at.
  List<SourceRef> _sourcesForProtocol() => switch (_protocol) {
        _CardioProtocol.calafiore => [
            AppSources.calafiore1995,
            AppSources.calafiore2020,
          ],
        _CardioProtocol.bretschneider => [
            AppSources.bretschneider1980,
            AppSources.bretschneider1975,
            AppSources.gebhard1984,
          ],
        _ => [
            AppSources.buckberg1987,
            AppSources.matteDelNido2012,
          ],
      };

  // ── Buckberg / del Nido: weight x ml/kg -> total/blood/crystalloid ───────
  // Currently unreachable from the UI (see _kVisibleProtocols) but kept
  // fully intact so the protocols can be switched back on without a rewrite.
  Widget _buildWeightBasedSection() {
    final isBuckberg = _protocol == _CardioProtocol.buckberg;

    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final hWeight = (v: patientData.cardioplegiaWeight, label: t('bsa_body_weight'));
    final hDose = isBuckberg
        ? (v: patientData.cardioplegiaDoseBuckberg, label: t('cardio_dose_per_kg'))
        : (v: patientData.cardioplegiaDoseDelNido,  label: t('cardio_dose_per_kg'));

    final totalVolume = isBuckberg ? patientData.buckbergDoseVolume : patientData.delNidoDoseVolume;
    final bloodVolume = isBuckberg ? patientData.buckbergBloodVolume : patientData.delNidoBloodVolume;
    final crystVolume = isBuckberg ? patientData.buckbergCrystalloidVolume : patientData.delNidoCrystalloidVolume;
    final showCappedNote = !isBuckberg && patientData.delNidoDoseCapped;

    return Column(children: [
      InputCard(label: t('bsa_body_weight'), unit: 'kg', value: patientData.cardioplegiaWeight,
          range: Ranges.weight,
          onChanged: (v) { patientData.cardioplegiaWeight = v; onChanged(); }),

      InputCard(
        label: t('cardio_dose_per_kg'),
        unit: 'ml/kg',
        value: isBuckberg ? patientData.cardioplegiaDoseBuckberg : patientData.cardioplegiaDoseDelNido,
        range: isBuckberg ? Ranges.cardioplegiaDoseBuckberg : Ranges.cardioplegiaDoseDelNido,
        step: isBuckberg ? 0.1 : 1,
        onChanged: (v) {
          if (isBuckberg) { patientData.cardioplegiaDoseBuckberg = v; } else { patientData.cardioplegiaDoseDelNido = v; }
          onChanged();
        },
      ),

      _protocolInfoCard(lines: [
        (Icons.opacity, isBuckberg ? t('cardio_ratio_buckberg') : t('cardio_ratio_delnido')),
        (Icons.speed, t('cardio_pressure_limits')),
        (Icons.repeat, isBuckberg ? t('cardio_interval_buckberg') : t('cardio_interval_delnido')),
      ]),

      SectionHeader(t('cardio_section_result')),
      ResultCard(label: t('cardio_total_volume'), unit: 'ml', value: totalVolume,
          decimals: 0, missingInputs: missing([hWeight, hDose])),
      ResultCard(label: t('cardio_blood_volume'), unit: 'ml', value: bloodVolume,
          decimals: 0, missingInputs: missing([hWeight, hDose])),
      ResultCard(label: t('cardio_crystalloid_volume'), unit: 'ml', value: crystVolume,
          decimals: 0, missingInputs: missing([hWeight, hDose])),

      if (showCappedNote)
        _noteRow(Icons.warning_amber_rounded, t('cardio_capped_note'),
            color: const Color(0xFFFFA726), textColor: kTextSecondary),
    ]);
  }

  // ── Calafiore: pressure-controlled warm blood cardioplegia ──────────────
  // Whole blood from the oxygenator is the carrier; a K+ (optionally with
  // Mg2+) syringe is continuously titrated in via a Perfusor. Delivery is
  // intermittent, and both the target [K+] and the separate end-of-dose
  // Mg2+ bolus change across the dose sequence (see the per-dose default
  // tables on PatientData). Because the institutional protocol runs the
  // antegrade line pressure-controlled (e.g. 90-100 mmHg) rather than
  // flow-controlled, the actual blood flow varies with coronary/graft
  // resistance - so the Perfusor rate must track the CURRENT flow to keep
  // the delivered [K+] constant for whichever dose is currently selected.
  Widget _buildCalafioreSection() {
    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final doseNumber = patientData.cardioplegiaCalafioreDoseNumber ?? 1;
    final hasTargetAlt = doseNumber >= 4 && doseNumber <= 6;

    // Magnesium is OPTIONAL: it is deliberately excluded from every
    // "missing input" list, so leaving it blank yields a pure-KCl syringe
    // and all K+ results still compute normally.
    final hKclVol = (v: patientData.cardioplegiaCalafioreKclVolume, label: t('cardio_kcl_volume'));
    final hKclConc = (v: patientData.cardioplegiaCalafioreKclConc, label: t('cardio_kcl_conc'));
    final hFlow = (v: patientData.cardioplegiaCalafioreFlow, label: t('cardio_flow'));
    final hSerumK = (v: patientData.cardioplegiaCalafioreSerumK, label: t('cardio_serum_k'));

    final syringeMissing = missing([hKclVol, hKclConc]);
    final rateMissing = missing([hKclVol, hKclConc, hFlow, hSerumK]);

    final showNoDoseNote = patientData.cardioplegiaCalafioreSerumK != null &&
        patientData.calafioreDeltaK == 0 &&
        rateMissing.isEmpty;

    // Displayed concentration values depend on the active unit; onChanged
    // always converts back to the canonical mmol/ml before storing.
    final kclConcMmol = patientData.cardioplegiaCalafioreKclConc;
    final kclIsPercent = _kclUnit == _kUnitPercent;
    final kclConcDisplay = (kclIsPercent && kclConcMmol != null)
        ? _mmolPerMlToPercent(kclConcMmol, _kKclMolarMass)
        : kclConcMmol;
    final mgConcMmol = patientData.cardioplegiaCalafioreMgConc;
    final mgIsPercent = _mgUnit == _kUnitPercent;
    final mgConcDisplay = (mgIsPercent && mgConcMmol != null)
        ? _mmolPerMlToPercent(mgConcMmol, _kMgso4MolarMass)
        : mgConcMmol;

    return Column(children: [
      _protocolInfoCard(lines: [
        (Icons.opacity, t('cardio_calafiore_principle')),
        (Icons.speed, t('cardio_pressure_limits')),
        (Icons.repeat, t('cardio_interval_calafiore')),
      ]),

      // Re-dose stopwatch: Calafiore is intermittent, the window opens at
      // 15 min and is exceeded past 20 min.
      _doseTimerCard(
        dueAfterMin: 15,
        overdueAfterMin: 20,
        windowText: t('cardio_timer_window_calafiore'),
      ),

      // ── Dose number selector (1-6, intermittent sequence) ───────────────
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('cardio_dose_number'), style: TextStyle(color: kText, fontSize: 14)),
          const SizedBox(height: 8),
          Row(children: [
            for (var d = 1; d <= 6; d++) ...[
              if (d > 1) const SizedBox(width: 6),
              Expanded(child: _doseChip(d, doseNumber)),
            ],
          ]),
        ]),
      ),

      // ── Effective target K+ for this dose, with alt selector on 4-6 ─────
      _effectiveValueCard(
        label: t('cardio_target_k'),
        valueText: '${patientData.calafioreTargetK.toStringAsFixed(0)} mmol/l',
        showAlt: hasTargetAlt,
        altLabel: t('cardio_target_alt_label'),
        altOptions: const [12.0, 10.0, 8.0],
        altUnit: 'mmol/l',
        altSelected: patientData.cardioplegiaCalafioreTargetKAlt ?? 12.0,
        onAltSelected: (v) { patientData.cardioplegiaCalafioreTargetKAlt = v; onChanged(); },
      ),

      // ── End-of-dose Mg2+ bolus (informational, fixed per dose) ──────────
      _effectiveValueCard(
        label: t('cardio_mg_bolus_display'),
        valueText: patientData.calafioreMgBolusMg >= 1000
            ? '${(patientData.calafioreMgBolusMg / 1000).toStringAsFixed(1)} g'
            : '${patientData.calafioreMgBolusMg.toStringAsFixed(0)} mg',
        // Dose 2 may be raised to 500 mg at the clinician's discretion.
        // That is shown as a plain hint rather than a selectable toggle,
        // since it feeds no calculation - a toggle would only change a
        // displayed number without any downstream effect.
        hint: doseNumber == 2 ? t('cardio_mg_bolus_dose2_hint') : null,
      ),

      SectionHeader(t('cardio_syringe_section')),
      InputCard(label: t('cardio_kcl_volume'), unit: 'ml', value: patientData.cardioplegiaCalafioreKclVolume,
          range: Ranges.cardioplegiaCalafioreKclVolume,
          step: 5, onChanged: (v) { patientData.cardioplegiaCalafioreKclVolume = v; onChanged(); }),
      InputCard(
        label: t('cardio_kcl_conc'),
        unit: _kclUnit,
        unitOptions: const [_kUnitMmolPerMl, _kUnitPercent],
        onUnitChanged: (u) => setState(() => _kclUnit = u),
        value: kclConcDisplay,
        range: kclIsPercent ? Ranges.cardioplegiaCalafioreKclConcPercent : Ranges.cardioplegiaCalafioreKclConc,
        step: kclIsPercent ? 0.5 : 0.1,
        onChanged: (v) {
          patientData.cardioplegiaCalafioreKclConc =
              (v == null) ? null : (kclIsPercent ? _percentToMmolPerMl(v, _kKclMolarMass) : v);
          onChanged();
        },
      ),

      InputCard(label: t('cardio_mg_volume'), unit: 'ml', value: patientData.cardioplegiaCalafioreMgVolume,
          range: Ranges.cardioplegiaCalafioreMgVolume,
          step: 5, onChanged: (v) { patientData.cardioplegiaCalafioreMgVolume = v; onChanged(); }),
      InputCard(
        label: t('cardio_mg_conc'),
        unit: _mgUnit,
        unitOptions: const [_kUnitMmolPerMl, _kUnitPercent],
        onUnitChanged: (u) => setState(() => _mgUnit = u),
        value: mgConcDisplay,
        range: mgIsPercent ? Ranges.cardioplegiaCalafioreMgConcPercent : Ranges.cardioplegiaCalafioreMgConc,
        step: mgIsPercent ? 1 : 0.1,
        onChanged: (v) {
          patientData.cardioplegiaCalafioreMgConc =
              (v == null) ? null : (mgIsPercent ? _percentToMmolPerMl(v, _kMgso4MolarMass) : v);
          onChanged();
        },
      ),
      _noteRow(Icons.info_outline, t('cardio_mg_optional_hint')),

      ResultCard(label: t('cardio_syringe_k_conc'), unit: 'mmol/ml', value: patientData.calafioreSyringeKConc,
          decimals: 2, missingInputs: syringeMissing),
      // No missingInputs on the Mg readout: a blank value here is a valid
      // "no magnesium added" configuration, not an incomplete entry.
      ResultCard(label: t('cardio_syringe_mg_conc'), unit: 'mmol/ml', value: patientData.calafioreSyringeMgConc,
          decimals: 3),

      SectionHeader(t('cardio_flow_section')),
      InputCard(label: t('cardio_flow'), unit: 'ml/min', value: patientData.cardioplegiaCalafioreFlow,
          range: Ranges.cardioplegiaCalafioreFlow,
          step: 10, onChanged: (v) { patientData.cardioplegiaCalafioreFlow = v; onChanged(); }),
      InputCard(label: t('cardio_serum_k'), unit: 'mmol/l', value: patientData.cardioplegiaCalafioreSerumK,
          range: Ranges.kalium,
          step: 0.1, onChanged: (v) { patientData.cardioplegiaCalafioreSerumK = v; onChanged(); }),

      SectionHeader(t('cardio_section_result')),
      ResultCard(label: t('cardio_perfusor_rate'), unit: 'ml/h', value: patientData.calafiorePerfusorRate,
          decimals: 1, missingInputs: rateMissing),
      ResultCard(label: t('cardio_mg_delivery'), unit: 'mmol/h', value: patientData.calafioreMgDeliveryRate,
          decimals: 2),

      if (showNoDoseNote)
        _noteRow(Icons.info_outline, t('cardio_no_dose_needed')),
    ]);
  }

  // ── Bretschneider (HTK/Custodiol) ───────────────────────────────────────
  // Single-shot intracellular crystalloid cardioplegia. The delivery has
  // two clinically distinct phases that differ in both duration and target
  // pressure, so the section is driven by a phase switch: it picks the
  // matching plausible time range (6-8 min induction vs. 2-3 min
  // re-perfusion) and the matching guidance text, instead of showing one
  // averaged set of numbers the user has to mentally filter.
  Widget _buildBretschneiderSection() {
    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final isReperfusion = patientData.cardioplegiaBretschneiderIsReperfusion;

    final hFlow = (v: patientData.cardioplegiaBretschneiderFlow, label: t('cardio_bret_flow'));
    final hTime = (v: patientData.cardioplegiaBretschneiderTime, label: t('cardio_bret_time'));

    return Column(children: [
      _protocolInfoCard(lines: [
        (Icons.science_outlined, t('cardio_bret_principle')),
        (Icons.speed, t('cardio_pressure_limits')),
        (Icons.timer_outlined, t('cardio_bret_ischemia')),
      ]),

      // Re-dose stopwatch: Bretschneider is a single shot whose protection
      // window closes at ~180 min - warn 30 min ahead so there is time to
      // prepare a re-infusion rather than being surprised at the limit.
      _doseTimerCard(
        dueAfterMin: 150,
        overdueAfterMin: 180,
        windowText: t('cardio_timer_window_bret'),
      ),

      // ── Phase switch (induction vs. re-perfusion) ───────────────────────
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('cardio_bret_phase'), style: TextStyle(color: kText, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: kTableHeaderBg, borderRadius: const BorderRadius.all(Radius.circular(20))),
            child: Row(children: [
              Expanded(child: _phaseBtn(t('cardio_bret_phase_initial'), false, isReperfusion)),
              Expanded(child: _phaseBtn(t('cardio_bret_phase_reperfusion'), true, isReperfusion)),
            ]),
          ),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: kGold, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(
              isReperfusion ? t('cardio_bret_guidance_reperfusion') : t('cardio_bret_guidance_initial'),
              style: TextStyle(color: kTextSecondary, fontSize: 12),
            )),
          ]),
        ]),
      ),

      SectionHeader(t('cardio_bret_pump_section')),
      InputCard(label: t('cardio_bret_flow'), unit: 'ml/min', value: patientData.cardioplegiaBretschneiderFlow,
          range: Ranges.cardioplegiaBretschneiderFlow,
          step: 10, onChanged: (v) { patientData.cardioplegiaBretschneiderFlow = v; onChanged(); }),
      InputCard(label: t('cardio_bret_time'), unit: 'min', value: patientData.cardioplegiaBretschneiderTime,
          // Plausible range follows the selected phase, so an entry that is
          // fine for one phase is flagged when it belongs to the other.
          range: isReperfusion
              ? Ranges.cardioplegiaBretschneiderTimeReperfusion
              : Ranges.cardioplegiaBretschneiderTimeInitial,
          step: 0.5, onChanged: (v) { patientData.cardioplegiaBretschneiderTime = v; onChanged(); }),
      ResultCard(label: t('cardio_bret_volume'), unit: 'ml', value: patientData.bretschneiderVolumeFromFlow,
          decimals: 0, missingInputs: missing([hFlow, hTime])),
    ]);
  }

  /// Re-dose interval stopwatch. Both protocols are time-critical, only the
  /// thresholds differ: Calafiore must be re-given every 15-20 min, while
  /// Bretschneider's single shot protects for ~180 min. Deliberately a
  /// manual stopwatch - it does not run in the background and does not
  /// claim to replace the perfusion record.
  Widget _doseTimerCard({required double dueAfterMin, required double overdueAfterMin, required String windowText}) {
    final last = patientData.cardioplegiaLastDoseAt;
    final elapsed = last == null ? null : DateTime.now().difference(last);
    final status = elapsed == null
        ? null
        : PatientData.cardioplegiaDoseStatus(
            elapsed: elapsed,
            dueAfterMin: dueAfterMin,
            overdueAfterMin: overdueAfterMin,
          );

    final (statusColor, statusText) = switch (status) {
      CardioplegiaDoseStatus.overdue => (const Color(0xFFE57373), t('cardio_timer_status_overdue')),
      CardioplegiaDoseStatus.due => (const Color(0xFFFFA726), t('cardio_timer_status_due')),
      CardioplegiaDoseStatus.ok => (kGold, t('cardio_timer_status_ok')),
      null => (kTextFaint, t('cardio_timer_never')),
    };

    String fmt(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return h > 0 ? '$h:$m:$s' : '$m:$s';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: status == CardioplegiaDoseStatus.ok || status == null
                ? Colors.transparent
                : statusColor,
            width: 1.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('cardio_timer_section'), style: TextStyle(color: kText, fontSize: 14)),
              Text(windowText, style: TextStyle(color: kTextMuted, fontSize: 11)),
            ])),
            const SizedBox(width: 10),
            Text(elapsed == null ? '—' : fmt(elapsed),
                style: TextStyle(color: statusColor, fontSize: 26, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
              status == CardioplegiaDoseStatus.overdue
                  ? Icons.warning_amber_rounded
                  : (status == CardioplegiaDoseStatus.due ? Icons.notifications_active_outlined : Icons.info_outline),
              color: statusColor, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _timerBtn(
              icon: Icons.play_arrow_rounded,
              label: t('cardio_timer_dose_now'),
              filled: true,
              onTap: () {
                setState(() => patientData.cardioplegiaLastDoseAt = DateTime.now());
                _syncTicker();
                widget.onChanged();
              },
            )),
            if (last != null) ...[
              const SizedBox(width: 8),
              Expanded(child: _timerBtn(
                icon: Icons.restart_alt,
                label: t('cardio_timer_reset'),
                filled: false,
                onTap: () {
                  setState(() => patientData.cardioplegiaLastDoseAt = null);
                  _syncTicker();
                  widget.onChanged();
                },
              )),
            ],
          ]),
          const SizedBox(height: 6),
          Text(t('cardio_timer_hint'), style: TextStyle(color: kTextFaint, fontSize: 10.5)),
        ]),
      ),
    );
  }

  Widget _timerBtn({required IconData icon, required String label, required bool filled, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: filled ? kGold : kSurfaceWash,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: filled ? Colors.black : kTextSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: filled ? Colors.black : kTextSecondary,
              fontSize: 12.5,
              fontWeight: filled ? FontWeight.bold : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _phaseBtn(String label, bool phaseIsReperfusion, bool current) {
    final active = phaseIsReperfusion == current;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          if (active) return;
          setState(() {
            patientData.cardioplegiaBretschneiderIsReperfusion = phaseIsReperfusion;
            // Clear the time so the previous phase's value isn't silently
            // carried into a phase where it would be implausible.
            patientData.cardioplegiaBretschneiderTime = null;
          });
          widget.onChanged();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: active ? kGold : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: active ? Colors.black : kTextMuted,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _noteRow(IconData icon, String text, {Color? color, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color ?? kTextGhost, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(color: textColor ?? kTextFaint, fontSize: 11.5))),
      ]),
    );
  }

  Widget _doseChip(int dose, int active) {
    final isActive = dose == active;
    return Semantics(
      button: true,
      selected: isActive,
      label: '$dose',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          setState(() {
            patientData.cardioplegiaCalafioreDoseNumber = dose;
            // Reset the dose-specific target override on switch, so a
            // choice made for one dose never silently carries over.
            patientData.cardioplegiaCalafioreTargetKAlt = null;
          });
          widget.onChanged();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? kGold : kSurfaceWash,
            border: Border.all(color: isActive ? kGold : Colors.transparent, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text('$dose',
              style: TextStyle(color: isActive ? Colors.black : kTextSecondary,
                  fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.normal))),
        ),
      ),
    );
  }

  /// A read-only display of an effective (dose-derived) value, with either
  /// an optional chip selector (target K+ on doses 4-6) or a plain hint.
  Widget _effectiveValueCard({
    required String label,
    required String valueText,
    bool showAlt = false,
    String? altLabel,
    List<double> altOptions = const [],
    String altUnit = '',
    double altSelected = 0,
    ValueChanged<double?>? onAltSelected,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: kText, fontSize: 14))),
            const SizedBox(width: 10),
            Text(valueText, style: TextStyle(color: kGold, fontSize: 18, fontWeight: FontWeight.w500)),
          ]),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: TextStyle(color: kTextFaint, fontSize: 11)),
          ],
          if (showAlt && altLabel != null && onAltSelected != null) ...[
            const SizedBox(height: 8),
            Text(altLabel, style: TextStyle(color: kTextFaint, fontSize: 11)),
            const SizedBox(height: 4),
            Row(children: [
              for (final opt in altOptions) ...[
                if (opt != altOptions.first) const SizedBox(width: 6),
                _altChip(opt, altUnit, opt == altSelected, () => onAltSelected(opt)),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _altChip(double value, String unit, bool active, VoidCallback onTap) {
    final label = '${value.toStringAsFixed(0)} $unit';
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? kGold.withValues(alpha: 0.18) : kSurfaceWash,
            border: Border.all(color: active ? kGold : Colors.transparent, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label, style: TextStyle(color: active ? kGold : kTextSecondary,
              fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _protocolInfoCard({required List<(IconData, String)> lines}) {
    final rows = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) rows.add(const SizedBox(height: 6));
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(lines[i].$1, color: kGold, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(lines[i].$2, style: TextStyle(color: kTextSecondary, fontSize: 12.5))),
      ]));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kSurfaceWash, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      ),
    );
  }

  Widget _toggleBtn(String label, _CardioProtocol protocol) {
    final active = _protocol == protocol;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _switchProtocol(protocol),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: active ? kGold : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: active ? Colors.black : kTextMuted,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        ),
      ),
    );
  }
}

// ── PDF sections (extracted, for the single-tab export and the combined report) ─
//
// Emits rows ONLY for protocols the user has actually entered data for.
// This matters for the combined report's "only filled-in tabs" filter
// (MainScreen._exportCombinedReport): the per-dose target [K+], the Mg2+
// bolus and the dose number all derive from defaults and therefore ALWAYS
// render a value. Emitting them unconditionally made the cardioplegia tab
// count as "filled" in every single report, even for cases where the tab
// was never opened. Gating each protocol block on its own user input fixes
// that at the source.
//
// Buckberg/del Nido rows are omitted entirely because those protocols are
// currently not selectable in the UI - re-add them here if
// _kVisibleProtocols is widened again.
bool _hasCalafioreInput(PatientData pd) =>
    pd.cardioplegiaCalafioreKclVolume != null ||
    pd.cardioplegiaCalafioreKclConc != null ||
    pd.cardioplegiaCalafioreMgVolume != null ||
    pd.cardioplegiaCalafioreMgConc != null ||
    pd.cardioplegiaCalafioreFlow != null ||
    pd.cardioplegiaCalafioreSerumK != null ||
    pd.cardioplegiaCalafioreDoseNumber != null;

bool _hasBretschneiderInput(PatientData pd) =>
    pd.cardioplegiaBretschneiderFlow != null ||
    pd.cardioplegiaBretschneiderTime != null;

List<PdfSection> buildCardioplegiaPdfSections(PatientData pd) {
  final calafiore = _hasCalafioreInput(pd);
  final bretschneider = _hasBretschneiderInput(pd);

  return [
    PdfSection(title: t('pdf_inputs'), rows: [
      if (calafiore) ...[
        PdfRow(label: '${t('cardio_dose_number')} (Calafiore)',
            value: '${pd.cardioplegiaCalafioreDoseNumber ?? 1}', unit: ''),
        PdfRow.numeric(label: '${t('cardio_kcl_volume')} (Calafiore)', value: pd.cardioplegiaCalafioreKclVolume, unit: 'ml'),
        PdfRow.numeric(label: '${t('cardio_kcl_conc')} (Calafiore)', value: pd.cardioplegiaCalafioreKclConc, unit: 'mmol/ml'),
        PdfRow.numeric(label: '${t('cardio_mg_volume')} (Calafiore)', value: pd.cardioplegiaCalafioreMgVolume, unit: 'ml'),
        PdfRow.numeric(label: '${t('cardio_mg_conc')} (Calafiore)', value: pd.cardioplegiaCalafioreMgConc, unit: 'mmol/ml'),
        PdfRow.numeric(label: '${t('cardio_flow')} (Calafiore)', value: pd.cardioplegiaCalafioreFlow, unit: 'ml/min'),
        PdfRow.numeric(label: '${t('cardio_serum_k')} (Calafiore)', value: pd.cardioplegiaCalafioreSerumK, unit: 'mmol/l'),
      ],
      if (bretschneider) ...[
        PdfRow.numeric(label: '${t('cardio_bret_flow')} (Bretschneider)', value: pd.cardioplegiaBretschneiderFlow, unit: 'ml/min'),
        PdfRow.numeric(label: '${t('cardio_bret_time')} (Bretschneider)', value: pd.cardioplegiaBretschneiderTime, unit: 'min', decimals: 1),
      ],
    ]),
    PdfSection(title: t('pdf_results'), rows: [
      if (calafiore) ...[
        PdfRow(label: '${t('cardio_target_k')} (Calafiore)',
            value: pd.calafioreTargetK.toStringAsFixed(0), unit: 'mmol/l'),
        PdfRow(label: '${t('cardio_mg_bolus_display')} (Calafiore)',
            value: pd.calafioreMgBolusMg.toStringAsFixed(0), unit: 'mg'),
        PdfRow.numeric(label: '${t('cardio_syringe_k_conc')} (Calafiore)', value: pd.calafioreSyringeKConc, unit: 'mmol/ml', decimals: 2),
        PdfRow.numeric(label: '${t('cardio_syringe_mg_conc')} (Calafiore)', value: pd.calafioreSyringeMgConc, unit: 'mmol/ml', decimals: 3),
        PdfRow.numeric(label: '${t('cardio_perfusor_rate')} (Calafiore)', value: pd.calafiorePerfusorRate, unit: 'ml/h', decimals: 1),
        PdfRow.numeric(label: '${t('cardio_mg_delivery')} (Calafiore)', value: pd.calafioreMgDeliveryRate, unit: 'mmol/h', decimals: 2),
      ],
      if (bretschneider)
        PdfRow.numeric(label: '${t('cardio_bret_volume')} (Bretschneider)', value: pd.bretschneiderVolumeFromFlow, unit: 'ml', decimals: 0),
    ]),
  ];
}
