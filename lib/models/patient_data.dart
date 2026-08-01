import 'dart:math';

class PatientData {
  // ── Internal helper: guards against NaN/Infinity in results ─────────────
  // Any calculation producing NaN or Infinity is treated as "no result" (0).
  // This prevents extreme inputs (e.g. pow overflow) from crashing the UI.
  static double _safe(double v) {
    if (v.isNaN || v.isInfinite) return 0;
    return v;
  }

  // BSA/CO inputs
  double? height;
  double? weight;
  double? primingVolume;
  double? currentHb;
  double? currentHct;

  // BSA screen Cardiac Index (persisted, default 2.4)
  // This is loaded/saved via SharedPreferences in BSAScreen
  double bsaCardiacIndex = 2.4;
  // Whether the user has actively changed the Cardiac Index in THIS session
  // (as opposed to the value automatically loaded from SharedPreferences or
  // the 2.4 default). Used to keep untouched default/preference values out
  // of the PDF export - see buildBsaPdfSections() in bsa_screen.dart. Does
  // NOT affect the actual calculation.
  bool bsaCardiacIndexTouched = false;

  // O2 delivery inputs
  double? paO2;
  double? pvO2;
  double? saO2;
  double? svO2;
  double? artHb;
  double? venHb;
  double? hzv;
  double? kof;
  double? cardiacIndex; // O2 tab CI manual override

  // Resistances inputs
  double? map;
  double? cvp;
  double? hzvRes;
  double? pap;
  double? lap;
  double? hzvPvr;

  // Electrolytes inputs
  double? bodyWeightElec;
  double? natriumIst;
  double? natriumSoll = 130;
  bool natriumSollTouched = false;
  double? kaliumIst;
  double? kaliumSoll = 4.8;
  bool kaliumSollTouched = false;
  double? calziumIst;
  double? calziumSoll = 1.2;
  bool calziumSollTouched = false;
  double? baseExcess;

  // Tube volume
  double? tubeLength;

  // Zoll/Charriere
  double? chInput;
  double? mmInput;

  // Pediatric
  double? pediatricWeight;
  double? desiredHbIncrease;

  // Ultrafiltration / hemoconcentration
  double? ufCurrentVolume;
  double? ufCurrentHct;
  double? ufTargetHct;
  double? ufCurrentHb;
  double? ufTargetHb;

  // Cardioplegia
  double? cardioplegiaWeight;
  double? cardioplegiaDoseBuckberg;  // ml/kg, induction/maintenance dose
  double? cardioplegiaDoseDelNido;   // ml/kg, single dose
  // (Calafiore fields are declared further below, next to their getters)

  // ── BSA/CO calculations ──────────────────────────────────────────────────
  double get bsa {
    if (height == null || weight == null) return 0;
    // Reject non-physiological or extreme inputs that would cause overflow
    if (height! <= 0 || weight! <= 0 || height! > 300 || weight! > 1000) return 0;
    final result = 0.007184 * pow(height!, 0.725) * pow(weight!, 0.425);
    return _safe(result.toDouble());
  }

  /// Cardiac output uses user-defined CI (default 2.4) instead of fixed value
  double get cardiacOutput => _safe(bsa * bsaCardiacIndex);

  // Weight-only linear approximation of the circulating blood volume, as
  // used in clinical perfusion practice (Silbernagl & Despopoulos,
  // Taschenatlas Physiologie - AppSources.silbernagl).
  //
  // OPEN POINT, deliberately not changed unilaterally: this is a textbook
  // approximation, while the project otherwise insists on primary
  // literature. Nadler WM, Hidalgo JU, Bloch T. Prediction of blood volume
  // in normal human adults. Surgery. 1962;51(2):224-232 is already cited as
  // AppSources.nadler but drives no calculation. Nadler additionally needs
  // body height (available as PatientData.height):
  //   male   BV(l) = 0.3669 x H(m)^3 + 0.03219 x W(kg) + 0.6041
  //   female BV(l) = 0.3561 x H(m)^3 + 0.03308 x W(kg) + 0.1833
  // Switching would move every displayed blood volume AND both expected
  // Hct/Hb values, and would make height a required input for them - a
  // clinical product decision, not a bug fix. Until it is taken, the UI
  // labels these two results as an approximation.
  double get bloodVolumeMale {
    if (weight == null || weight! <= 0) return 0;
    return 0.041 * weight! + 1.53;
  }

  double get bloodVolumeFemale {
    if (weight == null || weight! <= 0) return 0;
    return 0.047 * weight! + 0.86;
  }

  // Hemodilution after priming, for Hb exactly as for Hct below: the red
  // cell mass is unchanged, only the volume it is distributed in grows.
  //
  //   Hb_after = Hb_before x BV / (BV + priming)
  //
  // The previous implementation used a linearised form AND an implied blood
  // volume of weight x 100 ml (8000 ml at 80 kg), while the Hct getters
  // right below already used bloodVolumeMale/Female. At 80 kg / Hb 14 /
  // 1500 ml priming that produced 11.38 instead of 10.67 g/dl - a
  // systematic +0.70 g/dl, always on the optimistic side, in exactly the
  // range where transfusion is discussed. Hb is now split by sex like Hct,
  // because the underlying blood volume is.
  double _expectedHb(double bvLitres) {
    if (currentHb == null || primingVolume == null || bvLitres <= 0) return 0;
    final bvMl = bvLitres * 1000;
    return _safe(currentHb! * bvMl / (bvMl + primingVolume!));
  }

  double get expectedHbMale => _expectedHb(bloodVolumeMale);
  double get expectedHbFemale => _expectedHb(bloodVolumeFemale);

  double get expectedHctMale {
    if (weight == null || currentHct == null || primingVolume == null) return 0;
    final bvMale = bloodVolumeMale * 1000;
    if (bvMale <= 0) return 0;
    return currentHct! * bvMale / (bvMale + primingVolume!);
  }

  double get expectedHctFemale {
    if (weight == null || currentHct == null || primingVolume == null) return 0;
    final bvFemale = bloodVolumeFemale * 1000;
    if (bvFemale <= 0) return 0;
    return currentHct! * bvFemale / (bvFemale + primingVolume!);
  }

  // ── O2 delivery ──────────────────────────────────────────────────────────
  double get cardiacIndexEffective {
    if (cardiacIndex != null && cardiacIndex! > 0) return cardiacIndex!;
    if (hzv != null && hzv! > 0 && kof != null && kof! > 0) return hzv! / kof!;
    return 0;
  }

  double get _coEffective {
    if (hzv != null && hzv! > 0) return hzv!;
    if (cardiacIndex != null && cardiacIndex! > 0 && kof != null && kof! > 0) return cardiacIndex! * kof!;
    return 0;
  }

  double get _bsaEffective => kof ?? 0;

  double get caO2 {
    if (artHb == null || saO2 == null || paO2 == null) return 0;
    return (artHb! * 1.34 * (saO2! / 100)) + (paO2! * 0.0031);
  }

  double get cvO2 {
    if (venHb == null || svO2 == null || pvO2 == null) return 0;
    return (venHb! * 1.34 * (svO2! / 100)) + (pvO2! * 0.0031);
  }

  /// Arteriovenous oxygen content difference.
  ///
  /// Guarded on BOTH sides on purpose. cvO2 returns 0 when any venous input
  /// is missing, so an unguarded subtraction silently degenerates to
  /// cavDO2 == caO2 - and with it VO2 == DO2 and O2-ER == 100 %. On screen
  /// that was masked by ResultCard.missingInputs, but the PDF export has no
  /// such notion and printed a plausible-looking "O2-ER 100.00 %" into the
  /// one artefact that leaves the app. Returning 0 here makes every
  /// downstream getter fall back to "not calculated" in both places.
  double get cavDO2 {
    if (caO2 <= 0 || cvO2 <= 0) return 0;
    return caO2 - cvO2;
  }

  double get do2 {
    final co = _coEffective;
    if (co <= 0) return 0;
    return caO2 * co * 10;
  }

  double get do2i {
    final ci = cardiacIndexEffective;
    if (ci <= 0) return 0;
    return caO2 * ci * 10;
  }

  double get vo2 {
    final co = _coEffective;
    if (co <= 0) return 0;
    return cavDO2 * co * 10;
  }

  double get vo2i {
    final ci = cardiacIndexEffective;
    if (ci <= 0) return 0;
    return cavDO2 * ci * 10;
  }

  double get o2er {
    final d = do2;
    if (d <= 0) return 0;
    return (vo2 / d) * 100;
  }

  double get minCardiacOutput {
    final bsaVal = _bsaEffective;
    if (caO2 <= 0 || bsaVal <= 0) return 0;
    return (272 * bsaVal) / (caO2 * 10);
  }

  double get minHb {
    final co = _coEffective;
    final bsaVal = _bsaEffective;
    if (co <= 0 || bsaVal <= 0 || saO2 == null || paO2 == null) return 0;
    final num = (272 * bsaVal) - (10 * co * 0.0031 * paO2!);
    final den = 10 * co * 1.34 * (saO2! / 100);
    if (den <= 0) return 0;
    return num / den;
  }

  // ── Resistances ──────────────────────────────────────────────────────────
  double get svr {
    if (map == null || cvp == null || hzvRes == null || hzvRes! <= 0) return 0;
    return (map! - cvp!) / hzvRes! * 80;
  }

  double get pvr {
    if (pap == null || lap == null || hzvPvr == null || hzvPvr! <= 0) return 0;
    return (pap! - lap!) / hzvPvr! * 80;
  }

  // ── Electrolytes ─────────────────────────────────────────────────────────
  double get natriumBedarf {
    if (natriumIst == null || natriumSoll == null || bodyWeightElec == null) return 0;
    return ((natriumSoll! - natriumIst!) * bodyWeightElec! * 0.2) / 1.71;
  }

  double get kaliumBedarf {
    if (kaliumIst == null || kaliumSoll == null || bodyWeightElec == null) return 0;
    return ((kaliumSoll! - kaliumIst!) * bodyWeightElec! * 0.2) / 1.0;
  }

  double get calziumBedarf {
    if (calziumIst == null || calziumSoll == null || bodyWeightElec == null) return 0;
    return ((calziumSoll! - calziumIst!) * bodyWeightElec! * 0.2) / 0.225;
  }

  double get nabic {
    if (baseExcess == null || bodyWeightElec == null) return 0;
    return (baseExcess! * bodyWeightElec! * 3) / (-10);
  }

  double get tris {
    if (baseExcess == null || bodyWeightElec == null) return 0;
    return (baseExcess! * bodyWeightElec!) / (-10);
  }

  // ── Tube volume ───────────────────────────────────────────────────────────
  double get tubeVol12  => (tubeLength ?? 0) * 1.2668;
  double get tubeVol38  => (tubeLength ?? 0) * 0.7126;
  double get tubeVol14  => (tubeLength ?? 0) * 0.3167;
  double get tubeVol316 => (tubeLength ?? 0) * 0.1781;

  // ── Charriere ─────────────────────────────────────────────────────────────
  double get chToMm => (chInput ?? 0) / 3;
  double get mmToCh => (mmInput ?? 0) * 3;

  // ── Pediatric transfusion ─────────────────────────────────────────────────
  // Davies P, Robertson S, Hegde S, Greenwood R, Massey E, Davis P.
  // Calculating the required transfusion volume in children.
  // Transfusion. 2007;47(2):212-216. doi:10.1111/j.1537-2995.2007.01091.x
  //
  //   volume (ml) = weight (kg) x Hb increment (g/dl) x 3 / Hct(RBC unit)
  //
  // The Hct is a FRACTION, not a percentage. Davies' own worked example:
  // 20 kg x 2 g/dl x 3 / 0.6 = 200 ml = 10 ml/kg, which is the paper's
  // headline statement ("10 mL/kg gives an increment of 2 g/dL" at the UK
  // standard Hct of 0.6).
  //
  // The factor 3 does NOT already contain the unit's hematocrit - dividing
  // by it is the paper's formula, not a double correction. With the 0.55
  // assumed here the result is 5.45 ml/kg per g/dl versus 5.0 at a UK unit;
  // Davies measured an empirical transfusion factor of 5.02 ml/kg.
  //
  // 0.55 is an institutional assumption, and it is the one number in this
  // formula that varies between blood services: German RBC concentrates in
  // additive solution are specified at Hct 0.50-0.70. Erring low yields a
  // slightly larger volume, so check it against the unit label before use -
  // in neonates the difference is clinically relevant.
  static const double kRbcUnitHematocrit = 0.55;

  double get transfusionVolume {
    if (pediatricWeight == null || desiredHbIncrease == null) return 0;
    return _safe(
        pediatricWeight! * desiredHbIncrease! * 3 / kRbcUnitHematocrit);
  }

  // ── Ultrafiltration / hemoconcentration ─────────────────────────────────
  // Mass-conservation principle: ultrafiltration removes plasma water across
  // the filter membrane while red blood cells (and the hemoglobin they
  // carry) are retained in the circuit, so total red-cell mass stays
  // constant - equally true whether expressed as hematocrit or hemoglobin:
  //   Hct1 x V1 = Hct2 x V2       or       Hb1 x V1 = Hb2 x V2
  // Source: Klineberg PL, Kam CA, Johnson DC, Cartmill TB, Brown JJ.
  // Hematocrit and blood volume control during cardiopulmonary bypass with
  // the use of hemofiltration. Anesthesiology. 1984;60(5):478-480.
  //
  // The UI lets the user pick Hct OR Hb as the working metric (mirroring
  // the CO/CI toggle on the O2 delivery tab); only one pair is ever
  // populated at a time, the other is cleared on switch. These getters
  // don't need to know which mode is active - they simply use whichever
  // pair has both values set.
  ({double m1, double m2})? get _ufMetricPair {
    if (ufCurrentHct != null && ufTargetHct != null) {
      return (m1: ufCurrentHct!, m2: ufTargetHct!);
    }
    if (ufCurrentHb != null && ufTargetHb != null) {
      return (m1: ufCurrentHb!, m2: ufTargetHb!);
    }
    return null;
  }

  /// How much volume must be filtered off to raise the hematocrit/
  /// hemoglobin from its current value to the target value.
  double get ufVolumeToRemove {
    if (ufCurrentVolume == null || ufCurrentVolume! <= 0) return 0;
    final pair = _ufMetricPair;
    if (pair == null) return 0;
    if (pair.m1 <= 0 || pair.m2 <= 0) return 0;
    // Ultrafiltration can only concentrate blood, never dilute it - a
    // target at or below the current value is not achievable by
    // filtration alone.
    if (pair.m2 <= pair.m1) return 0;
    final result = ufCurrentVolume! * (1 - pair.m1 / pair.m2);
    return _safe(result);
  }

  /// Resulting circulating volume after the calculated amount has been
  /// filtered off. Only meaningful once ufVolumeToRemove is valid (>0).
  double get ufFinalVolume {
    final removed = ufVolumeToRemove;
    if (removed <= 0 || ufCurrentVolume == null) return 0;
    return _safe(ufCurrentVolume! - removed);
  }

  // ── Cardioplegia ─────────────────────────────────────────────────────────
  // Two established protocols, each with a fixed blood:crystalloid ratio.
  // The per-kg dose is user-adjustable (institutional protocols vary within
  // the published range); the ratio itself is a fixed protocol constant,
  // not user-editable.
  //
  // Buckberg blood cardioplegia: 4 parts blood to 1 part crystalloid,
  // induction and each maintenance (repeat) dose given at the same per-kg
  // rate every 15-20 min.
  // Source: Buckberg GD. Strategies and logic of cardioplegic delivery to
  // prevent, avoid, and reverse ischemic and reperfusion damage. J Thorac
  // Cardiovasc Surg. 1987;93:127-139.
  double get buckbergDoseVolume {
    if (cardioplegiaWeight == null || cardioplegiaDoseBuckberg == null) return 0;
    if (cardioplegiaWeight! <= 0 || cardioplegiaDoseBuckberg! <= 0) return 0;
    return _safe(cardioplegiaWeight! * cardioplegiaDoseBuckberg!);
  }
  double get buckbergBloodVolume => _safe(buckbergDoseVolume * 4 / 5);
  double get buckbergCrystalloidVolume => _safe(buckbergDoseVolume * 1 / 5);

  // del Nido cardioplegia: 4 parts crystalloid to 1 part whole blood (i.e.
  // the inverse ratio of Buckberg), delivered as a single dose capped at
  // 1000 ml, effective for up to ~90 min without redosing.
  // Source: Matte GS, del Nido PJ. History and use of del Nido cardioplegia
  // solution at Boston Children's Hospital. J Extra Corpor Technol.
  // 2012;44(3):98-103.
  double get _delNidoDoseVolumeRaw {
    if (cardioplegiaWeight == null || cardioplegiaDoseDelNido == null) return 0;
    if (cardioplegiaWeight! <= 0 || cardioplegiaDoseDelNido! <= 0) return 0;
    return cardioplegiaWeight! * cardioplegiaDoseDelNido!;
  }
  double get delNidoDoseVolume {
    final raw = _delNidoDoseVolumeRaw;
    if (raw <= 0) return 0;
    return _safe(raw > 1000 ? 1000 : raw);
  }
  /// True once the weight-based dose exceeds the standard 1000 ml single-dose
  /// ceiling and has therefore been capped.
  bool get delNidoDoseCapped => _delNidoDoseVolumeRaw > 1000;
  double get delNidoBloodVolume => _safe(delNidoDoseVolume * 1 / 5);
  double get delNidoCrystalloidVolume => _safe(delNidoDoseVolume * 4 / 5);

  // ── del Nido: mixing, delivery time and dose per kg ─────────────────────
  // Institutional delivery setup: the crystalloid pump runs at 100% of the
  // set flow and the blood pump follows at a fixed fraction of it, which
  // reproduces the configured crystalloid:blood ratio mechanically.
  //
  // The ratio is expressed as the crystalloid SHARE of the finished
  // cardioplegia in percent (80% = the classic 4:1). It is passed in as a
  // parameter rather than read from the settings singleton, so these
  // formulas stay pure and testable:
  //   blood        = crystalloid x (100 - p) / p
  //   total        = crystalloid x 100 / p
  //   blood flow   = set flow x (100 - p) / p        (follower fraction)
  //   total flow   = set flow x 100 / p
  //   delivery time = crystalloid / set flow  -- independent of the ratio,
  //                   because volume and flow scale by the same factor
  // Source: Matte GS, del Nido PJ. History and use of del Nido cardioplegia
  // solution at Boston Children's Hospital. J Extra Corpor Technol.
  // 2012;44(3):98-103.
  double? cardioplegiaDelNidoCrystalloid; // ml, crystalloid volume to prepare
  double? cardioplegiaDelNidoPumpFlow;    // ml/min, crystalloid pump at 100%

  /// Guard shared by all ratio-dependent results: outside 0-100 (exclusive)
  /// the blood share would be zero or negative and the ratio undefined.
  static bool _validShare(double p) => p > 0 && p < 100;

  /// Blood component the follower pump adds to the entered crystalloid
  /// volume, at the configured crystalloid share [crystalloidPercent].
  double delNidoBloodFromCrystalloid(double crystalloidPercent) {
    final c = cardioplegiaDelNidoCrystalloid;
    if (c == null || c <= 0 || !_validShare(crystalloidPercent)) return 0;
    return _safe(c * (100 - crystalloidPercent) / crystalloidPercent);
  }

  /// Resulting total cardioplegia volume (crystalloid + blood).
  double delNidoTotalFromCrystalloid(double crystalloidPercent) {
    final c = cardioplegiaDelNidoCrystalloid;
    if (c == null || c <= 0 || !_validShare(crystalloidPercent)) return 0;
    return _safe(c * 100 / crystalloidPercent);
  }

  /// Blood pump flow under the follower principle.
  double delNidoBloodPumpFlow(double crystalloidPercent) {
    final f = cardioplegiaDelNidoPumpFlow;
    if (f == null || f <= 0 || !_validShare(crystalloidPercent)) return 0;
    return _safe(f * (100 - crystalloidPercent) / crystalloidPercent);
  }

  /// Combined delivery flow of both pumps.
  double delNidoTotalFlow(double crystalloidPercent) {
    final f = cardioplegiaDelNidoPumpFlow;
    if (f == null || f <= 0 || !_validShare(crystalloidPercent)) return 0;
    return _safe(f * 100 / crystalloidPercent);
  }

  /// Follower fraction the blood pump has to be set to, in percent of the
  /// crystalloid pump (80% share -> 25%).
  double delNidoFollowerPercent(double crystalloidPercent) {
    if (!_validShare(crystalloidPercent)) return 0;
    return _safe((100 - crystalloidPercent) / crystalloidPercent * 100);
  }

  /// Time needed to deliver the prepared volume at the set flow (minutes).
  /// Ratio-independent: crystalloid volume and crystalloid flow are both
  /// unscaled, and scaling both sides by 100/p cancels out.
  double get delNidoDeliveryTimeMin {
    final c = cardioplegiaDelNidoCrystalloid;
    final f = cardioplegiaDelNidoPumpFlow;
    if (c == null || f == null || c <= 0 || f <= 0) return 0;
    return _safe(c / f);
  }

  /// Protocol recommendation for del Nido: ~20 ml/kg as a single dose,
  /// capped at 1000 ml. Source: Matte GS, del Nido PJ. J Extra Corpor
  /// Technol. 2012;44(3):98-103.
  static const double kDelNidoRecommendedMlPerKg = 20;
  static const double kDelNidoMaxSingleDoseMl = 1000;

  /// Ideal total cardioplegia volume from the 20 ml/kg recommendation.
  ///
  /// Deliberately NOT capped: the raw weight-based figure is shown so the
  /// user sees the hypothetical requirement for heavy patients rather than
  /// a silently truncated 1000 ml. The protocol ceiling is communicated
  /// separately via [delNidoRecommendedExceedsMax] and a UI hint - showing
  /// a capped number without saying so would hide the very case where the
  /// limit matters.
  double get delNidoRecommendedTotal {
    final w = cardioplegiaWeight;
    if (w == null || w <= 0) return 0;
    return _safe(w * kDelNidoRecommendedMlPerKg);
  }

  /// True once the weight-based recommendation exceeds the 1000 ml single
  /// dose the del Nido protocol provides for.
  bool get delNidoRecommendedExceedsMax =>
      delNidoRecommendedTotal > kDelNidoMaxSingleDoseMl;

  /// Total cardioplegia volume per kg body weight (ml/kg) - lets the
  /// prepared volume be checked against the protocol's weight-based dose
  /// (del Nido standard ~20 ml/kg, capped at 1000 ml).
  double delNidoTotalPerKg(double crystalloidPercent) {
    final w = cardioplegiaWeight;
    final total = delNidoTotalFromCrystalloid(crystalloidPercent);
    if (w == null || w <= 0 || total <= 0) return 0;
    return _safe(total / w);
  }

  // Calafiore intermittent warm blood cardioplegia, adapted for
  // pressure-controlled delivery (e.g. 90-100 mmHg antegrade line
  // pressure): instead of a fixed blood flow, flow varies with coronary/
  // graft resistance, so the potassium/magnesium syringe pump (Perfusor)
  // rate must track the CURRENT blood flow to keep the delivered [K+]
  // CONCENTRATION in the cardioplegia solution constant.
  //
  // Mass-balance derivation, verified against the institutional Excel
  // calculator's own worked example (its "text" sheet): "if the patient's
  // [K+] is 5.0 mEq/l, to provide a [K+] of 10 mEq/l at 200 ml/min we need
  // to adjust the syringe pump to 30 ml/h" (pure 2 mmol/ml KCl, no
  // dilution) - 10 mEq/l/mmol/l is that worked example's OWN target value,
  // not this app's target, which now follows the institutional dose
  // schedule below instead of a single fixed number.
  //
  // Per-dose target [K+] and end-of-dose Mg2+ bolus (institutional
  // protocol, intermittent delivery, doses given roughly every 15-20 min):
  //   Dose 1: target 20 mmol/l | Mg2+ bolus 1000 mg (1 g)
  //   Dose 2: target 12 mmol/l | Mg2+ bolus  100 mg (alt. 500 mg)
  //   Dose 3: target 12 mmol/l | Mg2+ bolus  100 mg
  //   Dose 4: target 12 mmol/l (alt. 10 or 8 mmol/l) | Mg2+ bolus 500 mg
  //   Dose 5: target 12 mmol/l (alt. 10 or 8 mmol/l) | Mg2+ bolus 100 mg
  //   Dose 6: target 12 mmol/l (alt. 10 or 8 mmol/l) | Mg2+ bolus 100 mg
  // The Mg2+ bolus is a discrete end-of-dose PUSH, separate from the
  // continuously-run K+/Mg2+ Perfusor syringe below (both mechanisms exist
  // side by side per institutional practice) - shown for reference only,
  // not part of the Perfusor rate calculation.
  //
  // The Perfusor syringe itself is an institutional K+/Mg2+ MIXTURE (not
  // pure KCl): drawn up from ampoules, e.g. 4 x 10 ml KCl 14.9%
  // (2 mmol/ml) + 1 x 10 ml MgSO4-heptahydrate 500 mg/ml (20 mmol per
  // 10 ml ampoule, i.e. ~2.0 mmol/ml - confirmed by direct inspection of
  // the institutional ampoule label; an earlier version of this app
  // incorrectly assumed a "10%"/~0.4 mmol/ml concentration), giving a
  // resulting diluted [K+] of 1.6 mmol/ml and [Mg2+] of 0.4 mmol/ml in the
  // 50 ml syringe - both components' ampoule counts, per-ampoule volume,
  // and concentration are individually adjustable to match institutional
  // practice.
  // Source (technique origin): Calafiore AM, Teodori G, Mezzetti A, Bosco G,
  // Verna AM, Di Giammarco G, Lapenna D. Intermittent antegrade warm blood
  // cardioplegia. Ann Thorac Surg. 1995;59(2):398-402.
  double? cardioplegiaCalafioreFlow;    // ml/min, current CPL pump (blood) flow
  double? cardioplegiaCalafioreSerumK;  // mmol/l, patient's current serum K+ (ABG)
  int? cardioplegiaCalafioreDoseNumber; // 1-6, which dose in the intermittent sequence
  double? cardioplegiaCalafioreTargetKAlt;  // mmol/l, only used for doses 4-6 (alt. 12/10/8)

  double? cardioplegiaCalafioreKclVolume; // ml, TOTAL KCl volume drawn into the syringe
  double? cardioplegiaCalafioreKclConc;   // mmol/ml, KCl stock concentration
  double? cardioplegiaCalafioreMgVolume;  // ml, TOTAL MgSO4 volume drawn in (OPTIONAL)
  double? cardioplegiaCalafioreMgConc;    // mmol/ml, MgSO4 stock concentration (OPTIONAL)

  static const Map<int, double> _calafioreTargetKDefaults = {1: 20, 2: 12, 3: 12, 4: 12, 5: 12, 6: 12};
  static const Map<int, double> _calafioreMgBolusDefaultsMg = {1: 1000, 2: 100, 3: 100, 4: 500, 5: 100, 6: 100};

  /// Effective target [K+] (mmol/l) for the currently selected dose: the
  /// institutional default for that dose number, or the alt override for
  /// doses 4-6 if one was chosen.
  double get calafioreTargetK {
    final dose = cardioplegiaCalafioreDoseNumber ?? 1;
    final hasAlt = dose >= 4 && dose <= 6;
    if (hasAlt && cardioplegiaCalafioreTargetKAlt != null) return cardioplegiaCalafioreTargetKAlt!;
    return _calafioreTargetKDefaults[dose] ?? 12;
  }

  /// Effective end-of-dose Mg2+ bolus (mg) for the currently selected dose -
  /// informational only, fixed per dose (dose 2 may be raised to 500 mg at
  /// the clinician's discretion; that is shown as a hint, not a toggle,
  /// since it does not feed any calculation).
  double get calafioreMgBolusMg {
    final dose = cardioplegiaCalafioreDoseNumber ?? 1;
    return _calafioreMgBolusDefaultsMg[dose] ?? 100;
  }

  /// Total volume of the prepared syringe. The MgSO4 component is optional:
  /// if it is left blank the syringe is pure KCl and every downstream
  /// calculation still works (the K+ concentration is then simply
  /// undiluted).
  double get calafioreSyringeTotalVolume {
    final kcl = cardioplegiaCalafioreKclVolume ?? 0;
    final mg = cardioplegiaCalafioreMgVolume ?? 0;
    return _safe(kcl + mg);
  }

  /// Resulting [K+] in the syringe (mmol/ml) after the (optional) MgSO4
  /// volume has diluted the KCl stock.
  double get calafioreSyringeKConc {
    final total = calafioreSyringeTotalVolume;
    if (total <= 0 || cardioplegiaCalafioreKclVolume == null || cardioplegiaCalafioreKclConc == null) return 0;
    return _safe(cardioplegiaCalafioreKclVolume! * cardioplegiaCalafioreKclConc! / total);
  }

  /// Resulting [Mg2+] in the syringe (mmol/ml). Returns 0 when no magnesium
  /// was added - that is a valid configuration, not a missing input.
  double get calafioreSyringeMgConc {
    final total = calafioreSyringeTotalVolume;
    if (total <= 0 || cardioplegiaCalafioreMgVolume == null || cardioplegiaCalafioreMgConc == null) return 0;
    return _safe(cardioplegiaCalafioreMgVolume! * cardioplegiaCalafioreMgConc! / total);
  }

  /// K+ concentration still needed above the patient's own serum level
  /// (mmol/l), relative to the effective per-dose target. Clamped at 0: if
  /// the patient's serum K+ already meets or exceeds the target, no
  /// further supplementation is needed - a negative Perfusor rate would be
  /// meaningless.
  double get calafioreDeltaK {
    if (cardioplegiaCalafioreSerumK == null) return 0;
    final delta = calafioreTargetK - cardioplegiaCalafioreSerumK!;
    return delta > 0 ? _safe(delta) : 0;
  }

  /// Perfusor (syringe pump) rate in ml/h that delivers exactly enough of
  /// the syringe mixture, at the CURRENT blood flow, to raise the
  /// cardioplegia solution to the effective per-dose target [K+] - this is
  /// the value that must be re-entered/recalculated whenever the
  /// pressure-controlled flow changes, to keep the delivered concentration
  /// constant.
  double get calafiorePerfusorRate {
    final flow = cardioplegiaCalafioreFlow;
    final deltaK = calafioreDeltaK;
    final kConc = calafioreSyringeKConc;
    if (flow == null || flow <= 0 || deltaK <= 0 || kConc <= 0) return 0;
    final massRatePerMin = deltaK * flow / 1000; // mmol/min
    final syringeRatePerMin = massRatePerMin / kConc; // ml/min
    return _safe(syringeRatePerMin * 60); // ml/h
  }

  /// Resulting continuous Mg2+ delivery rate (mmol/h) at the calculated
  /// Perfusor rate - a derived readout, not an independently titrated
  /// target, since both electrolytes are delivered by the same physical
  /// syringe/pump. Returns 0 if no magnesium was added to the syringe.
  /// Separate from the discrete end-of-dose Mg2+ bolus
  /// (calafioreMgBolusMg).
  double get calafioreMgDeliveryRate {
    final rate = calafiorePerfusorRate;
    final mgConc = calafioreSyringeMgConc;
    if (rate <= 0 || mgConc <= 0) return 0;
    return _safe(rate * mgConc);
  }

  // ── Bretschneider (HTK / Custodiol) crystalloid cardioplegia ────────────
  // Single-shot intracellular crystalloid solution: extracellular sodium is
  // lowered to intracellular levels, abolishing the electrochemical
  // gradient and thus conduction. Institutional/teaching parameters:
  //   Solution temperature: 5-8 °C
  //   Perfusion pressure: initially 100-110 mmHg, after arrest 40-50 mmHg
  //   Perfusion time:    6-8 min initial, 2-3 min on re-perfusion
  //   Ischemic tolerance: organ protection up to ~180 min single shot
  // Sources: Bretschneider HJ. Myocardial protection. Thorac Cardiovasc
  // Surg. 1980;28(5):295-302. | Bretschneider HJ, Hubner G, Knoll D,
  // Lohr B, Nordbeck H, Spieckermann PG. Myocardial resistance and
  // tolerance to ischemia: physiological and biochemical basis.
  // J Cardiovasc Surg (Torino). 1975;16(3):241-60. | Gebhard MM, Preusse
  // CJ, Schnabel PA, Bretschneider HJ. Different effects of cardioplegic
  // solution HTK during single or intermittent administration. Thorac
  // Cardiovasc Surg. 1984;32(5):271-6.
  double? cardioplegiaBretschneiderFlow;  // ml/min, CPL pump flow
  double? cardioplegiaBretschneiderTime;  // min, perfusion time

  /// Delivered volume from pump settings: flow x time.
  double get bretschneiderVolumeFromFlow {
    final flow = cardioplegiaBretschneiderFlow;
    final time = cardioplegiaBretschneiderTime;
    if (flow == null || time == null || flow <= 0 || time <= 0) return 0;
    return _safe(flow * time);
  }

  // ── Cardioplegia re-dose interval timer ─────────────────────────────────
  // Both protocols are time-critical in opposite ways: Calafiore is
  // intermittent and must be re-given every 15-20 min, while Bretschneider
  // is a single shot whose protection window closes at ~180 min. A single
  // "time since last dose" clock serves both - only the thresholds differ.
  //
  // The timestamp lives here (not in the screen's State) so it survives tab
  // switches and rebuilds, exactly like every other case value.
  DateTime? cardioplegiaLastDoseAt;

  /// Status of the re-dose interval. Kept as a pure function of an elapsed
  /// Duration rather than reading the clock internally, so it stays
  /// deterministic and unit-testable; the screen supplies
  /// DateTime.now().difference(cardioplegiaLastDoseAt).
  static CardioplegiaDoseStatus cardioplegiaDoseStatus({
    required Duration elapsed,
    required double dueAfterMin,
    required double overdueAfterMin,
  }) {
    final minutes = elapsed.inSeconds / 60.0;
    if (minutes >= overdueAfterMin) return CardioplegiaDoseStatus.overdue;
    if (minutes >= dueAfterMin) return CardioplegiaDoseStatus.due;
    return CardioplegiaDoseStatus.ok;
  }
}

/// Where the case currently sits inside the protocol's re-dose window.
enum CardioplegiaDoseStatus {
  /// Comfortably inside the interval.
  ok,

  /// The re-dose window has opened (Calafiore) or the protection window is
  /// running short (Bretschneider) - prepare the next delivery.
  due,

  /// The interval has been exceeded.
  overdue,
}
