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

const kAppVersion = '0.1.9';
const _kDark = Color(0xFF1C1C1C);
const _kGold = Color(0xFFFFA500);

void main() async {
  // Sprache aus SharedPreferences laden bevor die UI gerendert wird,
  // damit der erste Rebuild schon die richtige Sprache zeigt.
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleNotifier.instance.load();
  runApp(const PerfusionCalcApp());
}

class PerfusionCalcApp extends StatelessWidget {
  const PerfusionCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder lauscht auf den globalen LocaleNotifier.
    // Bei jedem Sprachwechsel wird der gesamte Widget-Tree neu aufgebaut,
    // damit alle t()-Aufrufe die neue Sprache sehen.
    return AnimatedBuilder(
      animation: LocaleNotifier.instance,
      builder: (context, _) => MaterialApp(
        title: t('app_title'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(primary: _kGold, surface: _kDark),
          scaffoldBackgroundColor: const Color(0xFF2C2C2C),
          appBarTheme: const AppBarTheme(backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0),
          useMaterial3: true,
        ),
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

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PatientData _patientData = PatientData();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Tabs-Definition: icon ist statisch, label wird per t() bei jedem Build
  /// frisch übersetzt. Wenn die Sprache wechselt, ruft AnimatedBuilder oben
  /// einen Rebuild aus und _tabsList() wird neu evaluiert.
  List<Map<String, dynamic>> _tabsList() => [
    {'key': 'tab_bsa',          'icon': Icons.monitor_heart_outlined},
    {'key': 'tab_o2',           'icon': Icons.air},
    {'key': 'tab_resistances',  'icon': Icons.compress},
    {'key': 'tab_electrolytes', 'icon': Icons.science_outlined},
    {'key': 'tab_tube_volume',  'icon': Icons.linear_scale},
    {'key': 'tab_flow',         'icon': Icons.water_drop_outlined},
    {'key': 'tab_zoll',         'icon': Icons.straighten},
    {'key': 'tab_hypothermia',  'icon': Icons.ac_unit},
    {'key': 'tab_pediatric',    'icon': Icons.child_care_outlined},
    {'key': 'tab_reference',    'icon': Icons.table_chart_outlined},
    {'key': 'tab_anatomy',      'icon': Icons.favorite_border},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimerDialog());
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  void _goToTab(int index) {
    Navigator.pop(context); // close drawer
    _tabController.animateTo(index);
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(t('disclaimer_title'),
            style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dLine(Icons.warning_amber_rounded, _kGold,        t('disclaimer_clinical'),    bold: true),
            _dLine(Icons.school_outlined,       Colors.white70, t('disclaimer_education')),
            _dLine(Icons.person_outline,        Colors.white70, t('disclaimer_personal')),
            _dLine(Icons.info_outline,          Colors.white70, t('disclaimer_noguarantee')),
            const Divider(color: Colors.white24, height: 24),
            Text(t('disclaimer_legal_title'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text(t('disclaimer_legal_1'),
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            Text(t('disclaimer_legal_2'),
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            Text(t('disclaimer_legal_3'),
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic)),
          ]),
        ),
        actions: [TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('disclaimer_understand'),
              style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 15)),
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
        backgroundColor: _kDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(t('info_title'),
            style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 18)),
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
          child: Text(t('close'), style: const TextStyle(color: _kGold)),
        )],
      ),
    );
  }

  Widget _iRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: _kGold, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ])),
    ],
  );

  // ── Drawer ─────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _kDark,
      // AnimatedBuilder lauscht direkt am LocaleNotifier. Ohne diesen Wrapper
      // würde der Drawer beim Sprachwechsel nicht neu rendern, weil er als
      // Overlay über der App liegt - der globale Rebuild der MaterialApp
      // erreicht den Drawer-Inhalt nicht, solange er offen ist.
      child: AnimatedBuilder(
        animation: LocaleNotifier.instance,
        builder: (context, _) => SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('PerfusionCalc',
                style: TextStyle(color: _kGold, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(t('navigation'),
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: Builder(
              builder: (context) {
                // tabs einmal pro Build holen, damit nicht 11x neu evaluiert.
                final tabs = _tabsList();
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: tabs.length,
                  itemBuilder: (ctx, i) {
                    final isActive = _tabController.index == i;
                    return InkWell(
                      onTap: () => _goToTab(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isActive ? _kGold.withValues(alpha: 0.12) : Colors.transparent,
                          border: isActive
                              ? const Border(left: BorderSide(color: _kGold, width: 3))
                              : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(children: [
                          Icon(tabs[i]['icon'] as IconData,
                              color: isActive ? _kGold : Colors.white54, size: 20),
                          const SizedBox(width: 14),
                          Expanded(child: Text(t(tabs[i]['key'] as String),
                              style: TextStyle(
                                color: isActive ? _kGold : Colors.white70,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ))),
                          if (isActive)
                            const Icon(Icons.chevron_right, color: _kGold, size: 18),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // ── Language switcher ────────────────────────────────────────────
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(t('language'),
                style: const TextStyle(color: Colors.white38,
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
                        color: isActive ? _kGold.withValues(alpha: 0.18) : Colors.white10,
                        border: Border.all(
                          color: isActive ? _kGold : Colors.transparent,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${loc.flag}  ${loc.displayName}',
                          style: TextStyle(
                            color: isActive ? _kGold : Colors.white70,
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
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('v$kAppVersion',
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ),
        ]),
      ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder lauscht direkt am LocaleNotifier. Damit baut sich der
    // gesamte MainScreen (inkl. TabBar, AppBar, TabBarView und allen
    // eingebetteten Screens) bei jedem Sprachwechsel sofort neu auf - ohne
    // dass der Nutzer erst einen Tab antippen muss.
    return AnimatedBuilder(
      animation: LocaleNotifier.instance,
      builder: (context, _) => Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          // Burger menu — left
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
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
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoDialog,
          ),
          // Close button — rightmost
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => SystemNavigator.pop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: _kDark,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: _kGold,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: _tabsList()
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
            BSAScreen(patientData: _patientData, onChanged: () => setState(() {})),
            O2DeliveryScreen(patientData: _patientData, onChanged: () => setState(() {})),
            ResistancesScreen(patientData: _patientData, onChanged: () => setState(() {})),
            ElectrolytesScreen(patientData: _patientData, onChanged: () => setState(() {})),
            TubeVolumeScreen(patientData: _patientData, onChanged: () => setState(() {})),
            FlowDrainageScreen(),
            ZollChairreScreen(patientData: _patientData, onChanged: () => setState(() {})),
            HypothermiaScreen(),
            PediatricScreen(patientData: _patientData, onChanged: () => setState(() {})),
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
              child: Container(color: const Color(0xFF1A1A1A)),
            ),
            SizedBox(
              width: 600,
              child: child,
            ),
            Expanded(
              child: Container(color: const Color(0xFF1A1A1A)),
            ),
          ]);
        }
        // On narrow screens (phone/tablet portrait) use full width
        return child;
      },
    );
  }
}
