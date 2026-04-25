import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../i18n/app_strings.dart';
import '../widgets/external_page_launcher.dart';

class HeartAnatomyScreen extends StatelessWidget {
  const HeartAnatomyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // Hero section: a single, clear call-to-action card
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon header
                  Row(children: const [
                    Icon(Icons.favorite_border, color: kGold, size: 28),
                    SizedBox(width: 12),
                    Text('Heart Anatomy', // English keeps "Heart Anatomy" - same in DE
                        style: TextStyle(color: kGold, fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 14),
                  Text(t('anat_open_description'),
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                  const SizedBox(height: 6),
                  Text('• ${t('anat_coronary_ant')}',
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  Text('• ${t('anat_coronary_post')}',
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  Text('• ${t('anat_cross_section')}',
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  Text('• ${t('anat_coronary_arteries')}',
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 18),

                  // Primary action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: kIsWeb
                          ? () => openExternalPage('anatomy.html')
                          : null,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(t('anat_open_button'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 8),
                    Text(t('anat_web_only_hint'),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Hint why this is a separate page
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(t('anat_compatibility_note'),
                      style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
