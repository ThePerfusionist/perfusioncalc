import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';
import '../models/cardioplegia_alarm_settings.dart';
import '../models/cardioplegia_settings.dart';
import '../utils/notification_service.dart';
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
/// Buckberg is intentionally NOT offered in the protocol picker right now
/// (see _kVisibleProtocols): it is not used at the institution this app is
/// maintained for. Its enum value, calculation code (PatientData.buckberg*),
/// tests and UI section are kept intact, so it can be re-enabled by adding
/// it back to _kVisibleProtocols - nothing has to be rewritten.
enum _CardioProtocol { buckberg, delNido, calafiore, bretschneider }

const List<_CardioProtocol> _kVisibleProtocols = [
  _CardioProtocol.calafiore,
  _CardioProtocol.bretschneider,
  _CardioProtocol.delNido,
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

  /// How many times the alert has already fired for the current delivery.
  /// Compared against CardioplegiaAlarmSettings.expectedFireCount() each
  /// tick, so a missed tick (app briefly backgrounded) still catches up
  /// instead of silently skipping the alert.
  int _alarmsFired = 0;

  /// Whether the OS currently permits notifications. Checked on init and
  /// after a permission request, so the UI can point the user at the
  /// system setting instead of silently failing to alert.
  bool _notificationsAllowed = true;

  /// Whether the notification service itself came up. Distinguished from
  /// [_notificationsAllowed] so a failed service start is reported as such
  /// instead of masquerading as a denied permission.
  bool _notificationsAvailable = true;

  /// The alarm settings are collapsed by default: this tab is about
  /// cardioplegia, and the reminder is a side feature that should not
  /// dominate the screen. Expanded state is per-session only - it is a view
  /// preference, not a clinical setting worth persisting.
  bool _alarmExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncTicker();
    _refreshPermission();
    // Rebuild when alarm settings change (they live in a global notifier).
    CardioplegiaAlarmSettings.instance.addListener(_onSettingsChanged);
    CardioplegiaSettings.instance.addListener(_onSettingsChanged);
  }

  Future<void> _refreshPermission() async {
    final svc = CardioplegiaNotifications.instance;
    await svc.ensureReady();
    final ok = await svc.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _notificationsAllowed = ok;
        _notificationsAvailable = svc.isAvailable;
      });
    }
  }

  /// (Re-)schedules the OS-level reminder for the current delivery.
  /// Called whenever the delivery timestamp or any alarm setting changes,
  /// so what the OS holds always matches what the UI shows.
  Future<void> _rescheduleReminder() async {
    final st = CardioplegiaAlarmSettings.instance;
    final last = patientData.cardioplegiaLastDoseAt;
    if (!st.enabled || last == null) {
      await CardioplegiaNotifications.instance.cancelAll();
      return;
    }
    await CardioplegiaNotifications.instance.scheduleReminders(
      from: last,
      intervalMinutes: st.triggerMinutes,
      repeat: st.repeat,
      sound: st.sound,
      vibration: st.vibration,
      title: t('cardio_alarm_notif_title'),
      body: t('cardio_alarm_notif_body'),
    );
  }

  void _onSettingsChanged() {
    // Settings changed -> the scheduled reminder has to follow.
    _rescheduleReminder();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    CardioplegiaAlarmSettings.instance.removeListener(_onSettingsChanged);
    CardioplegiaSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _syncTicker() {
    final needsTicker = patientData.cardioplegiaLastDoseAt != null;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _checkAlarm();
        setState(() {});
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
            // Wrap instead of Row+Expanded: with three protocols the longest
            // label ("Bretschneider") no longer fits on narrow screens and
            // used to break mid-word. Wrap sizes each chip to its content
            // and moves whatever does not fit onto a centred second line.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(color: kTableHeaderBg, borderRadius: const BorderRadius.all(Radius.circular(20))),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final p in _kVisibleProtocols) _toggleBtn(_protocolLabel(p), p),
                ],
              ),
            ),
          ]),
        ),

        switch (_protocol) {
          _CardioProtocol.calafiore => _buildCalafioreSection(),
          _CardioProtocol.bretschneider => _buildBretschneiderSection(),
          _CardioProtocol.delNido => _buildDelNidoSection(),
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
        _CardioProtocol.delNido => [AppSources.matteDelNido2012],
        _ => [
            AppSources.buckberg1987,
            AppSources.matteDelNido2012,
          ],
      };

  // ── Buckberg: weight x ml/kg -> total/blood/crystalloid ─────────────────
  // Currently unreachable from the UI (Buckberg is not in _kVisibleProtocols)
  // but kept intact so the protocol can be switched back on without a
  // rewrite. del Nido used to share this section; it now has its own
  // (_buildDelNidoSection), so the former dual-protocol branching here has
  // been removed as dead code.
  Widget _buildWeightBasedSection() {
    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final hWeight = (v: patientData.cardioplegiaWeight, label: t('bsa_body_weight'));
    final hDose = (v: patientData.cardioplegiaDoseBuckberg, label: t('cardio_dose_per_kg'));

    return Column(children: [
      InputCard(label: t('bsa_body_weight'), unit: 'kg', value: patientData.cardioplegiaWeight,
          range: Ranges.weight,
          onChanged: (v) { patientData.cardioplegiaWeight = v; onChanged(); }),

      InputCard(
        label: t('cardio_dose_per_kg'),
        unit: 'ml/kg',
        value: patientData.cardioplegiaDoseBuckberg,
        range: Ranges.cardioplegiaDoseBuckberg,
        step: 0.1,
        onChanged: (v) { patientData.cardioplegiaDoseBuckberg = v; onChanged(); },
      ),

      _protocolInfoCard(lines: [
        (Icons.opacity, t('cardio_ratio_buckberg')),
        (Icons.speed, t('cardio_pressure_limits')),
        (Icons.repeat, t('cardio_interval_buckberg')),
      ]),

      SectionHeader(t('cardio_section_result')),
      ResultCard(label: t('cardio_total_volume'), unit: 'ml', value: patientData.buckbergDoseVolume,
          decimals: 0, missingInputs: missing([hWeight, hDose])),
      ResultCard(label: t('cardio_blood_volume'), unit: 'ml', value: patientData.buckbergBloodVolume,
          decimals: 0, missingInputs: missing([hWeight, hDose])),
      ResultCard(label: t('cardio_crystalloid_volume'), unit: 'ml', value: patientData.buckbergCrystalloidVolume,
          decimals: 0, missingInputs: missing([hWeight, hDose])),
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
  // Single-shot intracellular crystalloid cardioplegia. The delivered
  // volume follows directly from the pump settings (flow x time); the
  // protocol-specific durations and pressures are shown as guidance in the
  // info card rather than being modelled as separate modes.
  Widget _buildBretschneiderSection() {
    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final hFlow = (v: patientData.cardioplegiaBretschneiderFlow, label: t('cardio_bret_flow'));
    final hTime = (v: patientData.cardioplegiaBretschneiderTime, label: t('cardio_bret_time'));

    return Column(children: [
      _protocolInfoCard(lines: [
        (Icons.science_outlined, t('cardio_bret_principle')),
        (Icons.speed, t('cardio_bret_pressure')),
        (Icons.schedule, t('cardio_bret_duration')),
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

      SectionHeader(t('cardio_bret_pump_section')),
      InputCard(label: t('cardio_bret_flow'), unit: 'ml/min', value: patientData.cardioplegiaBretschneiderFlow,
          range: Ranges.cardioplegiaBretschneiderFlow,
          step: 10, onChanged: (v) { patientData.cardioplegiaBretschneiderFlow = v; onChanged(); }),
      InputCard(label: t('cardio_bret_time'), unit: 'min', value: patientData.cardioplegiaBretschneiderTime,
          range: Ranges.cardioplegiaBretschneiderTime,
          step: 0.5, onChanged: (v) { patientData.cardioplegiaBretschneiderTime = v; onChanged(); }),
      ResultCard(label: t('cardio_bret_volume'), unit: 'ml', value: patientData.bretschneiderVolumeFromFlow,
          decimals: 0, missingInputs: missing([hFlow, hTime])),
    ]);
  }

  /// Fires the in-app alert when the configured trigger point is reached.
  /// Uses the pure expectedFireCount() schedule rather than an equality
  /// check on the elapsed time, so the alert cannot be missed just because
  /// a tick was skipped (e.g. the app was briefly backgrounded).
  void _checkAlarm() {
    final last = patientData.cardioplegiaLastDoseAt;
    if (last == null) return;
    final st = CardioplegiaAlarmSettings.instance;
    final expected = CardioplegiaAlarmSettings.expectedFireCount(
      elapsed: DateTime.now().difference(last),
      enabled: st.enabled,
      triggerMinutes: st.triggerMinutes,
      repeat: st.repeat,
    );
    if (expected > _alarmsFired) {
      _alarmsFired = expected;
      _playAlert();
    }
  }

  /// Supplementary in-app feedback when the trigger point passes while the
  /// app happens to be open. The actual alert is the scheduled OS
  /// notification (see CardioplegiaNotifications) - this only adds a haptic
  /// nudge. SystemSound.play() is deliberately NOT used: it is a no-op on
  /// Android and was the reason the old in-app alert stayed silent.
  void _playAlert() {
    if (CardioplegiaAlarmSettings.instance.vibration) HapticFeedback.heavyImpact();
  }

  /// Posts an immediate notification so the user can verify that sound and
  /// vibration actually come through on their device.
  Future<void> _testAlert() async {
    final st = CardioplegiaAlarmSettings.instance;
    _playAlert();
    await CardioplegiaNotifications.instance.showTest(
      sound: st.sound,
      vibration: st.vibration,
      title: t('cardio_alarm_notif_title'),
      body: t('cardio_alarm_notif_body'),
    );
  }

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
                setState(() {
                  patientData.cardioplegiaLastDoseAt = DateTime.now();
                  _alarmsFired = 0; // new delivery -> alert schedule restarts
                });
                _syncTicker();
                _rescheduleReminder();
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
                  setState(() {
                    patientData.cardioplegiaLastDoseAt = null;
                    _alarmsFired = 0;
                  });
                  _syncTicker();
                  _rescheduleReminder();
                  widget.onChanged();
                },
              )),
            ],
          ]),
          const SizedBox(height: 6),
          Text(t('cardio_timer_hint'), style: TextStyle(color: kTextFaint, fontSize: 10.5)),
          Divider(color: kDivider, height: 20),
          _alarmSettings(),
        ]),
      ),
    );
  }

  /// Alert configuration. Lives inside the timer card because it only ever
  /// governs that timer; all values are persisted by
  /// CardioplegiaAlarmSettings and restored on the next app start.
  Widget _alarmSettings() {
    final st = CardioplegiaAlarmSettings.instance;

    // One-line summary so the collapsed state still shows what is armed.
    final summary = st.enabled
        ? '${st.triggerMinutes.toStringAsFixed(0)} min'
            '${st.sound ? " · ${t('cardio_alarm_sound')}" : ""}'
            '${st.vibration ? " · ${t('cardio_alarm_vibration')}" : ""}'
        : t('cardio_alarm_off');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row doubles as the expand/collapse control.
      InkWell(
        onTap: () => setState(() => _alarmExpanded = !_alarmExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Icon(st.enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                size: 16, color: st.enabled ? kGold : kTextMuted),
            const SizedBox(width: 8),
            Text(t('cardio_alarm_section'), style: TextStyle(color: kText, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(child: Text(summary,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: st.enabled ? kGold : kTextFaint, fontSize: 12))),
            Switch(value: st.enabled, onChanged: (v) {
              st.setEnabled(v);
              if (v) setState(() => _alarmExpanded = true);
            }),
            Icon(_alarmExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: kTextMuted),
          ]),
        ),
      ),

      // Problems stay visible even when collapsed - they need action.
      if (!_notificationsAvailable) ...[
        _noteRow(Icons.error_outline, t('cardio_alarm_unavailable'),
            color: const Color(0xFFE57373), textColor: kTextSecondary),
        if (CardioplegiaNotifications.instance.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SelectableText(
              CardioplegiaNotifications.instance.lastError!,
              style: TextStyle(color: kTextFaint, fontSize: 10.5),
            ),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: _timerBtn(
            icon: Icons.refresh,
            label: t('cardio_alarm_retry'),
            filled: false,
            onTap: () async {
              await CardioplegiaNotifications.instance.initialise();
              await _refreshPermission();
              await _rescheduleReminder();
            },
          ),
        ),
      ],
      if (_notificationsAvailable && !_notificationsAllowed && st.enabled) ...[
        _noteRow(Icons.notifications_off_outlined, t('cardio_alarm_perm_missing'),
            color: const Color(0xFFFFA726), textColor: kTextSecondary),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: _timerBtn(
            icon: Icons.notifications_active_outlined,
            label: t('cardio_alarm_grant'),
            filled: true,
            onTap: () async {
              await CardioplegiaNotifications.instance.requestPermission();
              await _refreshPermission();
              await _rescheduleReminder();
            },
          ),
        ),
      ],

      if (st.enabled && _alarmExpanded) ...[
        const SizedBox(height: 8),
        // Trigger time: stepper plus presets instead of a full-width slider,
        // which took a disproportionate amount of vertical space.
        Row(children: [
          Expanded(child: Text(t('cardio_alarm_trigger'),
              style: TextStyle(color: kTextSecondary, fontSize: 12))),
          _stepBtn(Icons.remove, () => st.setTriggerMinutes(st.triggerMinutes - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${st.triggerMinutes.toStringAsFixed(0)} min',
                style: TextStyle(color: kGold, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          _stepBtn(Icons.add, () => st.setTriggerMinutes(st.triggerMinutes + 1)),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final m in const [5.0, 10.0, 15.0, 20.0, 30.0, 60.0])
            _presetChip(m, st.triggerMinutes == m, () => st.setTriggerMinutes(m)),
        ]),
        const SizedBox(height: 8),
        // Three toggles as chips in one wrapped row instead of three
        // full-width switch rows.
        Wrap(spacing: 4, runSpacing: 4, children: [
          _optionChip(t('cardio_alarm_sound'), st.sound, (v) => st.setSound(v)),
          _optionChip(t('cardio_alarm_vibration'), st.vibration, (v) => st.setVibration(v)),
          _optionChip(t('cardio_alarm_repeat'), st.repeat, (v) => st.setRepeat(v)),
          _plainChip(Icons.play_arrow_rounded, t('cardio_alarm_test'), _testAlert),
        ]),
        const SizedBox(height: 6),
        Text(t('cardio_alarm_scope_hint'), style: TextStyle(color: kTextFaint, fontSize: 10)),
      ],
    ]);
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => Semantics(
    button: true,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: kSurfaceWash, shape: BoxShape.circle),
        child: Icon(icon, size: 15, color: kTextSecondary),
      ),
    ),
  );

  Widget _presetChip(double minutes, bool active, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: active,
      label: '${minutes.toStringAsFixed(0)} min',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: active ? kGold.withValues(alpha: 0.18) : kSurfaceWash,
            border: Border.all(color: active ? kGold : Colors.transparent, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(minutes.toStringAsFixed(0),
              style: TextStyle(color: active ? kGold : kTextSecondary, fontSize: 11.5,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _optionChip(String label, bool active, ValueChanged<bool> onChanged) {
    return Semantics(
      toggled: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!active),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: active ? kGold.withValues(alpha: 0.18) : kSurfaceWash,
            border: Border.all(color: active ? kGold : Colors.transparent, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(active ? Icons.check : Icons.close, size: 12,
                color: active ? kGold : kTextMuted),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: active ? kGold : kTextSecondary, fontSize: 11.5)),
          ]),
        ),
      ),
    );
  }

  Widget _plainChip(IconData icon, String label, VoidCallback onTap) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: kTableHeaderBg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: kTextSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: kTextSecondary, fontSize: 11.5)),
        ]),
      ),
    ),
  );

  // ── del Nido: ratio, mixture, delivery time and dose per kg ─────────────
  // The institutional setup drives both pumps from one setting: crystalloid
  // at 100%, blood following at a fraction of it, which reproduces the
  // configured ratio mechanically. The ratio itself is a persisted
  // institutional setting (CardioplegiaSettings), not per-case data.
  Widget _buildDelNidoSection() {
    List<String> missing(List<({Object? v, String label})> fields) =>
        fields.where((f) => f.v == null).map((f) => f.label).toList();

    final cfg = CardioplegiaSettings.instance;
    final pct = cfg.delNidoCrystalloidPercent;

    final hCryst = (v: patientData.cardioplegiaDelNidoCrystalloid, label: t('cardio_dn_crystalloid'));
    final hFlow = (v: patientData.cardioplegiaDelNidoPumpFlow, label: t('cardio_dn_pump_flow'));
    final hWeight = (v: patientData.cardioplegiaWeight, label: t('bsa_body_weight'));

    return Column(children: [
      _protocolInfoCard(lines: [
        (Icons.opacity, t('cardio_ratio_delnido')),
        (Icons.speed, t('cardio_pressure_limits')),
        (Icons.repeat, t('cardio_interval_delnido')),
      ]),

      // Re-dose stopwatch: del Nido is a single dose effective for ~90 min,
      // warn 15 min ahead of that.
      _doseTimerCard(
        dueAfterMin: 75,
        overdueAfterMin: 90,
        windowText: t('cardio_interval_delnido'),
      ),

      // ── Persisted mixing ratio ──────────────────────────────────────────
      SectionHeader(t('cardio_dn_ratio_section')),
      InputCard(
        label: t('cardio_dn_cryst_percent'),
        unit: '%',
        value: pct,
        range: Ranges.cardioplegiaDelNidoCrystPercent,
        step: 1,
        onChanged: (v) { if (v != null) cfg.setDelNidoCrystalloidPercent(v); },
      ),
      // Blood share and ratio are derived, so they are shown read-only -
      // offering both as inputs would allow contradictory entries.
      _readOnlyRow(t('cardio_dn_blood_percent'), '${cfg.delNidoBloodPercent.toStringAsFixed(0)} %'),
      _readOnlyRow(t('cardio_dn_ratio_result'), '${cfg.delNidoRatio.toStringAsFixed(2)} : 1'),
      _readOnlyRow(t('cardio_dn_follower_pct'),
          '${patientData.delNidoFollowerPercent(pct).toStringAsFixed(1)} %'),
      _noteRow(Icons.info_outline, t('cardio_dn_ratio_hint')),

      // ── Mixture and delivery time ───────────────────────────────────────
      SectionHeader(t('cardio_dn_mix_section')),
      InputCard(label: t('cardio_dn_crystalloid'), unit: 'ml', value: patientData.cardioplegiaDelNidoCrystalloid,
          range: Ranges.cardioplegiaDelNidoCrystalloid,
          step: 50, onChanged: (v) { patientData.cardioplegiaDelNidoCrystalloid = v; onChanged(); }),
      InputCard(label: t('cardio_dn_pump_flow'), unit: 'ml/min', value: patientData.cardioplegiaDelNidoPumpFlow,
          range: Ranges.cardioplegiaDelNidoPumpFlow,
          step: 10, onChanged: (v) { patientData.cardioplegiaDelNidoPumpFlow = v; onChanged(); }),
      _noteRow(Icons.info_outline, t('cardio_dn_follower_hint')),

      ResultCard(label: t('cardio_dn_blood_label'), unit: 'ml', value: patientData.delNidoBloodFromCrystalloid(pct),
          decimals: 0, missingInputs: missing([hCryst])),
      ResultCard(label: t('cardio_dn_total'), unit: 'ml', value: patientData.delNidoTotalFromCrystalloid(pct),
          decimals: 0, missingInputs: missing([hCryst])),
      // Follower share is shown in the label so it always matches the
      // configured ratio instead of a hard-coded 25 %.
      ResultCard(
          label: '${t('cardio_dn_blood_flow')} '
              '(${t('cardio_dn_follower_word')} ${patientData.delNidoFollowerPercent(pct).toStringAsFixed(1)} %)',
          unit: 'ml/min', value: patientData.delNidoBloodPumpFlow(pct),
          decimals: 0, missingInputs: missing([hFlow])),
      ResultCard(label: t('cardio_dn_total_flow'), unit: 'ml/min', value: patientData.delNidoTotalFlow(pct),
          decimals: 0, missingInputs: missing([hFlow])),
      ResultCard(label: t('cardio_dn_time'), unit: 'min', value: patientData.delNidoDeliveryTimeMin,
          decimals: 1, missingInputs: missing([hCryst, hFlow])),

      // ── Dose per body weight ────────────────────────────────────────────
      SectionHeader(t('cardio_dn_perkg_section')),
      InputCard(label: t('bsa_body_weight'), unit: 'kg', value: patientData.cardioplegiaWeight,
          range: Ranges.weight,
          onChanged: (v) { patientData.cardioplegiaWeight = v; onChanged(); }),
      ResultCard(label: t('cardio_dn_ideal_total'), unit: 'ml', value: patientData.delNidoRecommendedTotal,
          decimals: 0, missingInputs: missing([hWeight])),
      if (patientData.delNidoRecommendedExceedsMax)
        _noteRow(Icons.warning_amber_rounded, t('cardio_dn_ideal_capped'),
            color: const Color(0xFFFFA726), textColor: kTextSecondary),
      ResultCard(label: t('cardio_dn_per_kg'), unit: 'ml/kg', value: patientData.delNidoTotalPerKg(pct),
          decimals: 1, missingInputs: missing([hCryst, hWeight])),
      _noteRow(Icons.info_outline, t('cardio_dn_per_kg_hint')),
    ]);
  }

  /// A derived value shown read-only, styled like a compact result row.
  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: kTextSecondary, fontSize: 13))),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: kGold, fontSize: 15, fontWeight: FontWeight.w500)),
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
          child: Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
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

bool _hasDelNidoInput(PatientData pd) =>
    pd.cardioplegiaDelNidoCrystalloid != null ||
    pd.cardioplegiaDelNidoPumpFlow != null;

bool _hasBretschneiderInput(PatientData pd) =>
    pd.cardioplegiaBretschneiderFlow != null ||
    pd.cardioplegiaBretschneiderTime != null;

List<PdfSection> buildCardioplegiaPdfSections(PatientData pd) {
  final calafiore = _hasCalafioreInput(pd);
  final bretschneider = _hasBretschneiderInput(pd);
  final delNido = _hasDelNidoInput(pd);
  // Ratio is an institutional setting, read from the persisted singleton.
  final dnPct = CardioplegiaSettings.instance.delNidoCrystalloidPercent;

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
      if (delNido) ...[
        PdfRow.numeric(label: '${t('cardio_dn_crystalloid')} (del Nido)', value: pd.cardioplegiaDelNidoCrystalloid, unit: 'ml', decimals: 0),
        PdfRow.numeric(label: '${t('cardio_dn_pump_flow')} (del Nido)', value: pd.cardioplegiaDelNidoPumpFlow, unit: 'ml/min', decimals: 0),
        PdfRow.numeric(label: '${t('cardio_dn_cryst_percent')} (del Nido)', value: dnPct, unit: '%', decimals: 0),
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
      if (delNido) ...[
        PdfRow.numeric(label: '${t('cardio_dn_blood_label')} (del Nido)', value: pd.delNidoBloodFromCrystalloid(dnPct), unit: 'ml', decimals: 0),
        PdfRow.numeric(label: '${t('cardio_dn_total')} (del Nido)', value: pd.delNidoTotalFromCrystalloid(dnPct), unit: 'ml', decimals: 0),
        PdfRow.numeric(label: '${t('cardio_dn_blood_flow')} (del Nido)', value: pd.delNidoBloodPumpFlow(dnPct), unit: 'ml/min', decimals: 0),
        PdfRow.numeric(label: '${t('cardio_dn_total_flow')} (del Nido)', value: pd.delNidoTotalFlow(dnPct), unit: 'ml/min', decimals: 0),
        PdfRow.numeric(label: '${t('cardio_dn_time')} (del Nido)', value: pd.delNidoDeliveryTimeMin, unit: 'min', decimals: 1),
        PdfRow.numeric(label: '${t('cardio_dn_per_kg')} (del Nido)', value: pd.delNidoTotalPerKg(dnPct), unit: 'ml/kg', decimals: 1),
      ],
    ]),
  ];
}
