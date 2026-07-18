import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/bsa_screen.dart';
import 'screens/o2_delivery_screen.dart';
import 'screens/resistances_screen.dart';
import 'screens/electrolytes_screen.dart';
import 'screens/tube_volume_screen.dart';
import 'screens/flow_drainage_screen.dart';
import 'screens/zoll_chairre_screen.dart';
import 'screens/hypothermia_screen.dart';
import 'screens/pediatric_screen.dart';
import 'screens/reference_pressure_screen.dart';
import 'screens/heart_anatomy_screen.dart';
import 'models/patient_data.dart';
import 'i18n/app_strings.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart' show kGold, kCardColor, kText, kTextSecondary,
    kTextTertiary, kTextMuted, kTextFaint, kTextGhost, kDivider, kSurfaceWash, kLetterbox;

const kAppVersion = '0.2.2';

void main() async {
  // Sprache + Theme aus SharedPreferences laden bevor die UI gerendert wird,
  // damit der erste Rebuild schon die richtige Sprache/Darstellung zeigt.
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleNotifier.instance.load();
  await ThemeNotifier.instance.load();
  runApp(const PerfusionCalcApp());
}

class PerfusionCalcApp extends StatelessWidget {
  const PerfusionCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder lauscht auf Sprache UND Theme. Bei jeder Änderung wird
    // der gesamte Widget-Tree neu aufgebaut, damit alle t()-Aufrufe und alle
    // theme-abhängigen Farb-Getter (kGold, kCardColor, ...) den aktuellen
    // Stand sehen.
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final PatientData _patientData = PatientData();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Tabs-Definition: icon ist statisch, label wird per t() bei jedem Build
  /// frisch übersetzt. Wenn die Sprache wechselt, ruft AnimatedBuilder oben
  /// einen Rebuild aus und _tabsList() wird neu evaluiert.
  ///
  /// Reihenfolge bewusst gewählt: BSA und O2 als zentrale Berechnungen zuerst,
  /// dann Hypothermie (Severinghaus, didaktisch besonders wichtig), gefolgt
  /// von Elektrolyten und Resistances (haemodynamische Folgegroessen). Danach
  /// paediatrische und schlauchbezogene Berechnungen, zum Schluss die reinen
  /// Referenz-/Anatomie-Tabs.
  static const List<Map<String, dynamic>> _kTabs = [
    {'key': 'tab_bsa',          'icon': Icons.monitor_heart_outlined},
    {'key': 'tab_o2',           'icon': Icons.air},
    {'key': 'tab_hypothermia',  'icon': Icons.ac_unit},
    {'key': 'tab_electrolytes', 'icon': Icons.science_outlined},
    {'key': 'tab_resistances',  'icon': Icons.compress},
    {'key': 'tab_pediatric',    'icon': Icons.child_care_outlined},
    {'key': 'tab_flow',         'icon': Icons.water_drop_outlined},
    {'key': 'tab_tube_volume',  'icon': Icons.linear_scale},
    {'key': 'tab_zoll',         'icon': Icons.straighten},
    {'key': 'tab_reference',    'icon': Icons.table_chart_outlined},
    {'key': 'tab_anatomy',      'icon': Icons.favorite_border},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 11, vsync: this);
    // WICHTIG für Performance: Der Listener darf NICHT bei jedem
    // Animationsframe setState auslösen, sonst wird der gesamte Widget-Tree
    // (AppBar, TabBar, alle 11 TabBarView-Children) 60x/Sekunde neu gebaut.
    // Wir rebuilden nur, wenn sich der Ziel-Index tatsächlich ändert - das
    // ist ausschließlich für die aktive Markierung im Drawer nötig.
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimerDialog());
  }

  /// Wird vom Betriebssystem aufgerufen, wenn sich Hell/Dunkel ändert
  /// (z.B. automatischer Wechsel bei Sonnenuntergang). Nur relevant, wenn
  /// der Nutzer "System" als Theme-Modus gewählt hat - ThemeNotifier prüft
  /// das selbst und ignoriert den Aufruf sonst.
  @override
  void didChangePlatformBrightness() {
    ThemeNotifier.instance.handlePlatformBrightnessChanged();
  }

  int _lastTabIndex = 0;
  void _onTabChanged() {
    final idx = _tabController.index;
    if (idx != _lastTabIndex) {
      _lastTabIndex = idx;
      // Nur ein leichter Rebuild für die Drawer-Markierung; die TabBar selbst
      // aktualisiert sich intern über den gemeinsamen Controller.
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

  /// Bewusst leer: Screens aktualisieren ihre Ergebnisse selbst (lokales
  /// setState im jeweiligen Screen-State). Siehe Kommentar am TabBarView.
  void _noop() {}

  // ── Dialogs ────────────────────────────────────────────────────────────────
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

  // ── Drawer ─────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: kCardColor,
      // AnimatedBuilder lauscht auf Sprache UND Theme. Ohne diesen Wrapper
      // würde der Drawer bei einem Wechsel nicht neu rendern, weil er als
      // Overlay über der App liegt - der globale Rebuild der MaterialApp
      // erreicht den Drawer-Inhalt nicht, solange er offen ist.
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
                // tabs einmal pro Build holen, damit nicht 11x neu evaluiert.
                final tabs = _kTabs;
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: tabs.length,
                  itemBuilder: (ctx, i) {
                    final isActive = _tabController.index == i;
                    return InkWell(
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
                          Icon(tabs[i]['icon'] as IconData,
                              color: isActive ? kGold : kTextMuted, size: 20),
                          const SizedBox(width: 14),
                          Expanded(child: Text(t(tabs[i]['key'] as String),
                              style: TextStyle(
                                color: isActive ? kGold : kTextSecondary,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ))),
                          if (isActive)
                            Icon(Icons.chevron_right, color: kGold, size: 18),
                        ]),
                      ),
                    );
                  },
                );
              },
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder lauscht auf Sprache UND Theme. Damit baut sich der
    // gesamte MainScreen (inkl. TabBar, AppBar, TabBarView und allen
    // eingebetteten Screens) bei jedem Sprach- oder Theme-Wechsel sofort neu
    // auf - ohne dass der Nutzer erst einen Tab antippen muss.
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
          ),
          // Close button — rightmost
          IconButton(
            icon: Icon(Icons.close, color: kText),
            onPressed: () => SystemNavigator.pop(),
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
              tabs: _kTabs
                  .map((tab) => Tab(text: t(tab['key'] as String)))
                  .toList(),
            ),
          ),
        ),
      ),
      body: _webResponsiveBody(
        TabBarView(
          controller: _tabController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // onChanged ist bewusst ein No-Op: Jeder Screen aktualisiert seine
            // eigenen Ergebnisse über ein lokales setState. Ein globaler Rebuild
            // des MainScreen (und damit aller 11 Tabs) ist nicht nötig und war
            // die Hauptursache für das ruckelige Tippverhalten.
            BSAScreen(patientData: _patientData, onChanged: _noop),
            O2DeliveryScreen(patientData: _patientData, onChanged: _noop),
            HypothermiaScreen(),
            ElectrolytesScreen(patientData: _patientData, onChanged: _noop),
            ResistancesScreen(patientData: _patientData, onChanged: _noop),
            PediatricScreen(patientData: _patientData, onChanged: _noop),
            FlowDrainageScreen(),
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
