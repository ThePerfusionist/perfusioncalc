import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, visibleForTesting, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/bsa_screen.dart';
import 'screens/o2_delivery_screen.dart';
import 'screens/resistances_screen.dart';
import 'screens/electrolytes_screen.dart';
import 'screens/ultrafiltration_screen.dart';
import 'screens/tube_volume_screen.dart';
import 'screens/zoll_chairre_screen.dart';
import 'screens/hypothermia_screen.dart';
import 'screens/cardioplegia_screen.dart';
import 'screens/pediatric_screen.dart';
import 'screens/reference_pressure_screen.dart';
import 'screens/heart_anatomy_screen.dart';
import 'models/patient_data.dart';
import 'models/bga_model.dart';
import 'models/cardioplegia_alarm_settings.dart';
import 'models/cardioplegia_settings.dart';
import 'models/transfusion_settings.dart';
import 'utils/notification_service.dart';
import 'i18n/app_strings.dart';
import 'theme/app_theme.dart';
import 'utils/pdf_export.dart';
import 'widgets/common.dart' show kGold, kCardColor, kText, kTextSecondary,
    kTextTertiary, kTextMuted, kTextFaint, kTextGhost, kDivider, kSurfaceWash, kLetterbox;

const kAppVersion = '0.4.23';

void main() async {
  // Load language + theme from SharedPreferences before the UI is rendered,
  // so the first rebuild already shows the correct language/appearance.
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleNotifier.instance.load();
  await ThemeNotifier.instance.load();
  await CardioplegiaAlarmSettings.instance.load();
  await CardioplegiaSettings.instance.load();
  await TransfusionSettings.instance.load();
  await CardioplegiaNotifications.instance.initialise();
  runApp(const PerfusionCalcApp());
}

class PerfusionCalcApp extends StatelessWidget {
  const PerfusionCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder listens for language AND theme. On any change, the
    // entire widget tree is rebuilt, so all t() calls and all theme-
    // dependent color getters (kGold, kCardColor, ...) see the current
    // state.
    return AnimatedBuilder(
      animation: Listenable.merge([LocaleNotifier.instance, ThemeNotifier.instance]),
      builder: (context, _) => MaterialApp(
        title: t('app_title'),
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(dark: false),
        darkTheme: buildAppTheme(dark: true),
        themeMode: ThemeNotifier.instance.mode,
        home: const MainScreen(),
      ),
    );
  }
}

/// Alle Tabs, die etwas in den Gesamtbericht beitragen koennen - in der
/// Reihenfolge der Tableiste.
///
/// Ausgelagert und @visibleForTesting (Eigenbefund v0.4.12): Die Liste war
/// eine handgepflegte Kopie der Tabreihenfolge mitten in einer privaten
/// Methode. Ein neuer Rechen-Tab haette hier ergaenzt werden muessen, und
/// nichts haette daran erinnert - dieselbe Fehlerklasse wie das frueher fest
/// verdrahtete `TabController(length: 12)`, nur leiser: statt einer
/// Ausnahme beim Start haette schlicht ein Abschnitt im ausgelieferten
/// Bericht gefehlt.
///
/// [MainScreen.kTabs] enthaelt zwei weitere Tabs, die bewusst NICHT
/// auftauchen: `tab_reference` und `tab_anatomy` zeigen ausschliesslich
/// statische Nachschlagewerte und haben keine PDF-Sektionen. Ein Test
/// prueft genau diese Differenz.
@visibleForTesting
List<PdfTabReport> buildCombinedReportCandidates(PatientData pd, BgaModel bga) => [
  PdfTabReport(tabTitle: t('tab_bsa'),             sections: buildBsaPdfSections(pd)),
  PdfTabReport(tabTitle: t('tab_o2'),              sections: buildO2PdfSections(pd)),
  PdfTabReport(tabTitle: t('tab_hypothermia'),     sections: buildHypothermiaPdfSections(bga)),
  PdfTabReport(tabTitle: t('tab_cardioplegia'),    sections: buildCardioplegiaPdfSections(pd)),
  PdfTabReport(tabTitle: t('tab_electrolytes'),    sections: buildElectrolytesPdfSections(pd)),
  PdfTabReport(tabTitle: t('tab_ultrafiltration'), sections: buildUltrafiltrationPdfSections(pd)),
  PdfTabReport(tabTitle: t('tab_resistances'),     sections: buildResistancesPdfSections(pd)),
  PdfTabReport(tabTitle: t('tab_pediatric'),       sections: buildPediatricPdfSections(pd)),
  PdfTabReport(tabTitle: t('tab_tube_volume'),     sections: buildTubeVolumePdfSections(pd)),
  PdfTabReport(tabTitle: t('tab_zoll'),            sections: buildZollPdfSections(pd)),
];

/// Tabs ohne Rechenergebnisse - reine Nachschlagewerke.
@visibleForTesting
const kNonComputingTabKeys = {'tab_reference', 'tab_anatomy'};

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// Tab definition: icon is static, label is freshly translated via t() on
  /// every build. When the language switches, the AnimatedBuilder above
  /// triggers a rebuild and _tabsList() is re-evaluated.
  ///
  /// Order chosen deliberately: BSA and O2 as the central calculations
  /// first, then hypothermia (Severinghaus, didactically especially
  /// important), followed by electrolytes and resistances (downstream
  /// hemodynamic quantities). Then pediatric and tube-related
  /// calculations, and finally the pure reference/anatomy tabs.
  ///
  /// A record type instead of `List<Map<String, dynamic>>`: the map version
  /// needed an `as String` / `as IconData` cast at every single access, and
  /// a typo in a field name would only have shown up at runtime.
  @visibleForTesting
  static const List<({String key, IconData icon})> kTabs = [
    (key: 'tab_bsa',            icon: Icons.monitor_heart_outlined),
    (key: 'tab_o2',             icon: Icons.air),
    (key: 'tab_hypothermia',    icon: Icons.ac_unit),
    (key: 'tab_cardioplegia',   icon: Icons.bloodtype_outlined),
    (key: 'tab_electrolytes',   icon: Icons.science_outlined),
    (key: 'tab_ultrafiltration', icon: Icons.opacity),
    (key: 'tab_resistances',    icon: Icons.compress),
    (key: 'tab_pediatric',      icon: Icons.child_care_outlined),
    (key: 'tab_tube_volume',    icon: Icons.linear_scale),
    (key: 'tab_zoll',           icon: Icons.straighten),
    (key: 'tab_reference',      icon: Icons.table_chart_outlined),
    (key: 'tab_anatomy',        icon: Icons.favorite_border),
  ];

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final PatientData _patientData = PatientData();
  final BgaModel _bgaModel = BgaModel();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Derived, not a literal 12 next to a 12-entry list - the classic way
    // for a new tab to be added and the controller to be forgotten.
    _tabController = TabController(length: MainScreen.kTabs.length, vsync: this);
    // IMPORTANT for performance: the listener must NOT trigger setState on
    // every animation frame, or the entire widget tree (AppBar, TabBar, all
    // 12 TabBarView children) would rebuild 60x/second. We only rebuild
    // when the target index actually changes - that's only needed for the
    // active highlight in the drawer.
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimerDialog());
  }

  /// Called by the OS when light/dark changes (e.g. an automatic switch at
  /// sunset). Only relevant if the user has chosen "System" as the theme
  /// mode - ThemeNotifier checks this itself and otherwise ignores the
  /// call.
  @override
  void didChangePlatformBrightness() {
    ThemeNotifier.instance.handlePlatformBrightnessChanged();
  }

  int _lastTabIndex = 0;
  void _onTabChanged() {
    final idx = _tabController.index;
    if (idx != _lastTabIndex) {
      _lastTabIndex = idx;
      // Just a light rebuild for the drawer highlight; the TabBar itself
      // updates internally via the shared controller.
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    Navigator.pop(context); // close drawer
    _tabController.animateTo(index);
  }

  /// Deliberately empty: screens update their own results locally (local
  /// setState in the respective screen state). See the comment on
  /// TabBarView.
  void _noop() {}

  // ── Dialogs ──────────────────────────────────────────────────────────────
  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(t('disclaimer_title'),
            style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dLine(Icons.warning_amber_rounded, kGold,          t('disclaimer_clinical'),    bold: true),
            _dLine(Icons.school_outlined,       kTextSecondary, t('disclaimer_education')),
            _dLine(Icons.person_outline,        kTextSecondary, t('disclaimer_personal')),
            _dLine(Icons.info_outline,          kTextSecondary, t('disclaimer_noguarantee')),
            Divider(color: kDivider, height: 24),
            Text(t('disclaimer_legal_title'),
                style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text(t('disclaimer_legal_1'),
                style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            Text(t('disclaimer_legal_2'),
                style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            Text(t('disclaimer_legal_3'),
                style: TextStyle(color: kTextTertiary, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic)),
          ]),
        ),
        actions: [TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('disclaimer_understand'),
              style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 15)),
        )],
      ),
    );
  }

  Widget _dLine(IconData icon, Color color, String text, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: TextStyle(color: color, fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
    ]),
  );

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(t('info_title'),
            style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _iRow(Icons.tag,                 t('info_version'), 'v$kAppVersion'),
          const SizedBox(height: 10),
          _iRow(Icons.gavel_outlined,      t('info_license'), 'GNU General Public License v3.0'),
          const SizedBox(height: 10),
          _iRow(Icons.smart_toy_outlined,  t('info_created'), t('info_created_value')),
          const SizedBox(height: 10),
          _iRow(Icons.code,                t('info_github'),  'github.com/ThePerfusionist/perfusioncalc'),
          const SizedBox(height: 10),
          _iRow(Icons.mail_outline,        t('info_contact'), 'perfusioncalc@unbox.at'),
        ]),
        actions: [TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('close'), style: TextStyle(color: kGold)),
        )],
      ),
    );
  }

  Widget _iRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: kGold, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: kText, fontSize: 14)),
      ])),
    ],
  );

  // ── Combined report (combined PDF export across multiple tabs) ─────────────
  //
  // Ten tabs with an actual patient/case data connection belong in a
  // "patient report" (BSA, O2 delivery, hypothermia/BGA correction,
  // cardioplegia, electrolytes, ultrafiltration, resistances, pediatrics,
  // tube volume, Charrière). Their models (_patientData, _bgaModel) live
  // in MainScreen and are passed down to the respective screens - which is
  // exactly why they can be accessed directly here, without needing to
  // know the currently visible tab widgets. Reference pressures and heart
  // anatomy are pure, patient-independent reference tools and are
  // excluded - which is why they have no PDF export at all.
  //
  // "Only filled-in tabs": a tab is only included if at least one of its
  // rows has a real value (not just "—"). This keeps the report compact
  // even if the user has only worked through part of the tabs.
  Future<void> _exportCombinedReport() async {
    final candidates = buildCombinedReportCandidates(_patientData, _bgaModel);
    final filled = candidates.where((tab) =>
        tab.sections.any((s) => s.rows.any((r) => r.value != '—'))).toList();

    if (filled.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('combined_report_empty')), duration: const Duration(seconds: 4)),
      );
      return;
    }

    try {
      await exportCombinedReportAsPdf(tabs: filled);
    } catch (e, stack) {
      debugPrint('[CombinedReport] export failed: $e');
      debugPrint('$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t('pdf_export_failed')}: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // ── Drawer ───────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: kCardColor,
      // AnimatedBuilder listens for language AND theme. Without this
      // wrapper, the drawer wouldn't re-render on a change, because it sits
      // as an overlay above the app - the global MaterialApp rebuild
      // doesn't reach the drawer content while it's open.
      child: AnimatedBuilder(
        animation: Listenable.merge([LocaleNotifier.instance, ThemeNotifier.instance]),
        builder: (context, _) => SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('PerfusionCalc',
                style: TextStyle(color: kGold, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(t('navigation'),
                style: TextStyle(color: kTextFaint, fontSize: 12)),
          ),
          Divider(color: kDivider, height: 1),
          Expanded(
            child: Builder(
              builder: (context) {
                // fetch tabs once per build, so it's not re-evaluated 11x.
                final tabs = MainScreen.kTabs;
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: tabs.length,
                  itemBuilder: (ctx, i) {
                    final isActive = _tabController.index == i;
                    return Semantics(
                      button: true,
                      selected: isActive,
                      label: t(tabs[i].key),
                      excludeSemantics: true,
                      child: InkWell(
                      onTap: () => _goToTab(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isActive ? kGold.withValues(alpha: 0.12) : Colors.transparent,
                          border: isActive
                              ? Border(left: BorderSide(color: kGold, width: 3))
                              : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(children: [
                          Icon(tabs[i].icon,
                              color: isActive ? kGold : kTextMuted, size: 20),
                          const SizedBox(width: 14),
                          Expanded(child: Text(t(tabs[i].key),
                              style: TextStyle(
                                color: isActive ? kGold : kTextSecondary,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ))),
                          if (isActive)
                            Icon(Icons.chevron_right, color: kGold, size: 18),
                        ]),
                      ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // ── Combined report (combined PDF export) ────────────────────────────
          Divider(color: kDivider, height: 1),
          InkWell(
            onTap: () {
              Navigator.pop(context); // close the drawer, then trigger the export
              _exportCombinedReport();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Icon(Icons.picture_as_pdf_outlined, color: kGold, size: 20),
                const SizedBox(width: 14),
                Expanded(child: Text(t('combined_report_button'),
                    style: TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 14))),
              ]),
            ),
          ),
          // ── Theme switcher ────────────────────────────────────────────────
          Divider(color: kDivider, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(t('theme'),
                style: TextStyle(color: kTextFaint,
                    fontSize: 11, fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              (ThemeMode.system, Icons.brightness_auto, 'theme_system'),
              (ThemeMode.light, Icons.light_mode, 'theme_light'),
              (ThemeMode.dark, Icons.dark_mode, 'theme_dark'),
            ].map((entry) {
              final (mode, icon, labelKey) = entry;
              final isActive = ThemeNotifier.instance.mode == mode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    button: true,
                    selected: isActive,
                    label: '${t(labelKey)}${isActive ? ", ${t('a11y_selected')}" : ""}',
                    excludeSemantics: true,
                    child: InkWell(
                    onTap: () async {
                      await ThemeNotifier.instance.setMode(mode);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? kGold.withValues(alpha: 0.18) : kSurfaceWash,
                        border: Border.all(
                          color: isActive ? kGold : Colors.transparent,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 16, color: isActive ? kGold : kTextSecondary),
                        const SizedBox(height: 3),
                        Text(
                          t(labelKey),
                          style: TextStyle(
                            color: isActive ? kGold : kTextSecondary,
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ]),
                    ),
                    ),
                  ),
                ),
              );
            }).toList()),
          ),
          // ── Language switcher ────────────────────────────────────────────
          Divider(color: kDivider, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(t('language'),
                style: TextStyle(color: kTextFaint,
                    fontSize: 11, fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: AppLocale.values.map((loc) {
              final isActive = LocaleNotifier.instance.current == loc;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    button: true,
                    selected: isActive,
                    label: '${loc.displayName}${isActive ? ", ${t('a11y_selected')}" : ""}',
                    excludeSemantics: true,
                    child: InkWell(
                    onTap: () async {
                      await LocaleNotifier.instance.setLocale(loc);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? kGold.withValues(alpha: 0.18) : kSurfaceWash,
                        border: Border.all(
                          color: isActive ? kGold : Colors.transparent,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${loc.flag}  ${loc.displayName}',
                          style: TextStyle(
                            color: isActive ? kGold : kTextSecondary,
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
              );
            }).toList()),
          ),
          Divider(color: kDivider, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('v$kAppVersion',
                style: TextStyle(color: kTextGhost, fontSize: 11)),
          ),
        ]),
      ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder listens for language AND theme. This makes the
    // entire MainScreen (incl. TabBar, AppBar, TabBarView, and all embedded
    // screens) rebuild immediately on every language or theme switch -
    // without the user having to tap a tab first.
    return AnimatedBuilder(
      animation: Listenable.merge([LocaleNotifier.instance, ThemeNotifier.instance]),
      builder: (context, _) => Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          // Burger menu — left
          IconButton(
            icon: Icon(Icons.menu, color: kText),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: t('a11y_open_menu'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Text('PerfusionCalc', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          // Info button
          IconButton(
            icon: Icon(Icons.info_outline, color: kText),
            onPressed: _showInfoDialog,
            tooltip: t('a11y_app_info'),
          ),
          // Close button — rightmost. Android only: SystemNavigator.pop()
          // is a no-op on web, and an app that terminates itself is a
          // documented App Store rejection reason under the iOS HIG.
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            IconButton(
              icon: Icon(Icons.close, color: kText),
              onPressed: () => SystemNavigator.pop(),
              tooltip: t('a11y_close_app'),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: kCardColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: kGold,
              labelColor: kText,
              unselectedLabelColor: kTextMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: MainScreen.kTabs.map((tab) => Tab(text: t(tab.key))).toList(),
            ),
          ),
        ),
      ),
      body: _webResponsiveBody(
        TabBarView(
          controller: _tabController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // onChanged is deliberately a no-op: each screen updates its own
            // results via a local setState. A global rebuild of MainScreen
            // (and thus all 12 tabs) is not necessary and was the main
            // cause of the janky typing behavior.
            BSAScreen(patientData: _patientData, onChanged: _noop),
            O2DeliveryScreen(patientData: _patientData, onChanged: _noop),
            HypothermiaScreen(bgaModel: _bgaModel, onChanged: _noop),
            CardioplegiaScreen(patientData: _patientData, onChanged: _noop),
            ElectrolytesScreen(patientData: _patientData, onChanged: _noop),
            UltrafiltrationScreen(patientData: _patientData, onChanged: _noop),
            ResistancesScreen(patientData: _patientData, onChanged: _noop),
            PediatricScreen(patientData: _patientData, onChanged: _noop),
            TubeVolumeScreen(patientData: _patientData, onChanged: _noop),
            ZollChairreScreen(patientData: _patientData, onChanged: _noop),
            ReferencePressureScreen(),
            HeartAnatomyScreen(),
          ],
        ),
      ),
      ),
    );
  }

  // ── Responsive wrapper: constrains width on wide screens (web/tablet) ─────
  Widget _webResponsiveBody(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On wide screens center the content in a max-width column
        if (constraints.maxWidth > 640) {
          return Row(children: [
            Expanded(
              child: Container(color: kLetterbox),
            ),
            SizedBox(
              width: 600,
              child: child,
            ),
            Expanded(
              child: Container(color: kLetterbox),
            ),
          ]);
        }
        // On narrow screens (phone/tablet portrait) use full width
        return child;
      },
    );
  }
}
