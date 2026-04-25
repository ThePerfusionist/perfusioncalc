import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../i18n/app_strings.dart';

class HeartAnatomyScreen extends StatelessWidget {
  const HeartAnatomyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          const SizedBox(height: 8),

          // ── 1. Anterior view ───────────────────────────────────────────────
          _sectionTitle(t('anat_coronary_ant')),
          const SizedBox(height: 8),
          _imageCard(
            assetPath: 'assets/heart_anterior.png',
            caption: t('anat_desc_ant'),
            isSvg: false,
          ),

          const SizedBox(height: 20),

          // ── 2. Posterior view ──────────────────────────────────────────────
          _sectionTitle(t('anat_coronary_post')),
          const SizedBox(height: 8),
          _imageCard(
            assetPath: 'assets/heart_posterior.png',
            caption: t('anat_desc_post'),
            isSvg: false,
          ),

          const SizedBox(height: 20),

          // ── 3. Cross-section ───────────────────────────────────────────────
          _sectionTitle(t('anat_cross_section')),
          const SizedBox(height: 8),
          _imageCard(
            assetPath: 'assets/heart_cross_section.png',
            caption: t('anat_desc_cross'),
            isSvg: false,
            whiteBg: true,
          ),

          const SizedBox(height: 20),

          // ── 4. Coronary arteries schematic (SVG) ──────────────────────────
          _sectionTitle(t('anat_coronary_arteries')),
          const SizedBox(height: 8),
          _imageCard(
            assetPath: 'assets/coronary_arteries.svg',
            caption: t('anat_desc_schema'),
            isSvg: true,
            whiteBg: true,
          ),

          const SizedBox(height: 16),

          // ── Source ────────────────────────────────────────────────────────
          const SourceButton(refs: [
            AppSources.heartAnatomyWikipedia,
            AppSources.blausenMedical,
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Section title identical to other tabs ─────────────────────────────────
  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.bold),
  );

  // ── Image card with caption and zoom dialog ───────────────────────────────
  Widget _imageCard({
    required String assetPath,
    required String caption,
    required bool isSvg,
    bool whiteBg = false,
  }) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _showFullscreen(context, assetPath, isSvg, whiteBg: whiteBg),
        child: Container(
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Image with max-height so it doesn't blow up on wide screens
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: Container(
                  color: whiteBg ? Colors.white : null,
                  // SVGs werden ueber BrowserSafeImage ebenso als <img>-Tag
                  // im DOM gerendert - das funktioniert in jedem Browser
                  // unabhaengig von Flutters CanvasKit/flutter_svg, die in
                  // einigen Privacy-Browsern Probleme machen koennen.
                  child: BrowserSafeImage(
                    assetPath: assetPath,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Caption + zoom hint
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  caption,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 6),
                Row(children: const [
                  Icon(Icons.zoom_in, color: Colors.white24, size: 14),
                  SizedBox(width: 4),
                  Text('Tap to zoom', style: TextStyle(color: Colors.white24, fontSize: 11)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Full-screen zoom dialog ───────────────────────────────────────────────
  void _showFullscreen(BuildContext context, String assetPath, bool isSvg,
      {bool whiteBg = false}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: whiteBg ? Colors.white : const Color(0xFF0A0A0A),
        insetPadding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(children: [
          // Zoomable image
          Padding(
            padding: const EdgeInsets.all(4),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6.0,
              child: Center(
                child: BrowserSafeImage(assetPath: assetPath, fit: BoxFit.contain),
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
          // Zoom hint
          Positioned(
            bottom: 12, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t('anat_pinch_zoom'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
