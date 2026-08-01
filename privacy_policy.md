# Datenschutzerklärung / Privacy Policy — PerfusionCalc

**Stand / Last updated:** 01.08.2026 · **Gilt für / Applies to:** PerfusionCalc Android-App, iOS-App, Web-App ([perfusioncalc.de](https://perfusioncalc.de)) und die Offline-Windows-Distribution.

Online-Fassung / online version: **https://perfusioncalc.de/privacy.html**

---

# Deutsch

## 1. Verantwortlicher

Nils Röder

E-Mail: perfusioncalc@unbox.at

## 2. Kurzfassung

**PerfusionCalc erhebt keine personenbezogenen Daten.** Es gibt keine Registrierung, kein Nutzerkonto, keine Analytics, kein Tracking, keine Werbung, keine Werbe-IDs, keine Crash-Reporting-Dienste und keine Weitergabe an Dritte. Alle Berechnungen laufen ausschließlich auf dem Gerät.

## 3. Eingegebene Patienten- und Messwerte

Alle in der App eingegebenen Werte (Größe, Gewicht, Hb/Hkt, Blutgase, Elektrolyte, Flussraten, Kardioplegie-Parameter usw.) werden **ausschließlich im Arbeitsspeicher** verarbeitet. Sie werden nicht auf ein Speichermedium geschrieben, nicht in ein Backup übernommen und nicht übertragen. Beim Schließen der App bzw. beim Neuladen der Webseite gehen sie verloren.

Ausnahme: Wenn Sie selbst über die Export-Funktion ein PDF erzeugen, enthält diese Datei die von Ihnen eingegebenen Werte. Die Datei entsteht lokal auf Ihrem Gerät an dem von Ihnen gewählten Speicherort. Ab diesem Zeitpunkt liegt sie in Ihrer Verantwortung — insbesondere, wenn sie Patientenbezug aufweist.

## 4. Lokal gespeicherte Einstellungen

In der geräteeigenen Ablage (Android/iOS: `SharedPreferences`; Web: `localStorage`) werden ausschließlich Programmeinstellungen abgelegt:

| Gespeichert | Zweck |
|---|---|
| Sprachauswahl (DE/EN) | Oberflächensprache über Neustarts hinweg |
| Design (Hell/Dunkel/System) | Darstellung |
| Kardioplegie-Alarmeinstellungen (Intervall, Ton, Vibration, Wiederholung) | Erinnerungsfunktion |
| del-Nido-Mischungsverhältnis | zuletzt genutztes Protokoll |

Diese Einträge enthalten keine personenbezogenen Daten. Sie lassen sich durch Deinstallation der App bzw. durch Löschen der Websitedaten im Browser vollständig entfernen.

Die Android-App ist ausdrücklich von der Google-Cloud-Sicherung und von der Geräte-zu-Gerät-Übertragung ausgenommen (`android:allowBackup="false"`, `data_extraction_rules.xml`). Auch diese Einstellungen verlassen das Gerät also nicht.

## 5. Berechtigungen der Android-App

| Berechtigung | Zweck |
|---|---|
| `POST_NOTIFICATIONS` | Anzeige der Kardioplegie-Re-Dosis-Erinnerung |
| `SCHEDULE_EXACT_ALARM` | zeitgenaue Auslösung dieser Erinnerung |
| `RECEIVE_BOOT_COMPLETED` | Wiederherstellung geplanter Erinnerungen nach einem Neustart |
| `WAKE_LOCK` | Aufwecken des Displays bei Auslösung |
| `VIBRATE` | optionale Vibration |

Die Erinnerungsfunktion ist optional und wird ausschließlich lokal auf dem Gerät geplant. Es gibt keinen Push-Dienst und keinen Server.

**Der Release-Build der Android-App deklariert keine `INTERNET`-Berechtigung.** Die App ist damit technisch außerstande, Daten zu übertragen. Das ist im Manifest der veröffentlichten Fassung nachprüfbar.

## 6. Web-App (perfusioncalc.de)

Die Web-App wird als statische Seite über GitHub Pages ausgeliefert (GitHub, Inc., 88 Colin P. Kelly Jr. Street, San Francisco, CA 94107, USA). Beim Abruf verarbeitet GitHub als Hosting-Dienstleister technisch notwendige Verbindungsdaten — insbesondere IP-Adresse, Zeitpunkt, angeforderte Ressource und User-Agent — in Server-Logfiles. Auf diese Verarbeitung besteht kein Einfluss; sie ist für die Auslieferung jeder Webseite unvermeidbar. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse am technischen Betrieb). Einzelheiten: [GitHub Privacy Statement](https://docs.github.com/site-policy/privacy-policies/github-privacy-statement) und [GitHub Pages Data Collection](https://docs.github.com/pages/getting-started-with-github-pages/about-github-pages#data-collection).

Die Anwendung selbst lädt **keine** externen Ressourcen: keine CDNs, keine Schriftarten von Drittanbietern, keine Analyse-Skripte, keine Cookies. Die verwendete Schriftart (Roboto, Apache-2.0) ist seit Version 0.4.3 im Programm enthalten und wird nicht von einem Google-Server nachgeladen. Ein Service Worker legt die Programmdateien im Browser-Cache ab, damit die Anwendung offline funktioniert; dabei werden keine Eingabedaten gespeichert.

Der Browser fragt beim Aktivieren der Erinnerungsfunktion nach der Berechtigung für Benachrichtigungen. Diese wird lokal erteilt und lokal ausgewertet.

## 7. Offline-Windows-Distribution

Das Windows-Bundle enthält die Web-App und einen lokalen Webserver (Caddy), der ausschließlich an `localhost` gebunden ist. Es besteht keine Verbindung nach außen.

## 8. Empfänger, Drittland, automatisierte Entscheidungen

Es findet keine Weitergabe an Dritte statt — mit Ausnahme der unter Ziffer 6 beschriebenen, technisch unvermeidbaren Verarbeitung durch den Hosting-Dienstleister. Es erfolgt keine automatisierte Entscheidungsfindung und kein Profiling.

## 9. Speicherdauer

Da keine Daten erhoben werden, entfällt eine Speicherdauer. Lokale Einstellungen verbleiben bis zur Deinstallation bzw. bis zum Löschen der Websitedaten auf Ihrem Gerät.

## 10. Ihre Rechte

Ihnen stehen die Rechte nach Art. 15–21 DSGVO zu (Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit, Widerspruch) sowie das Beschwerderecht bei einer Aufsichtsbehörde nach Art. 77 DSGVO. Da keine personenbezogenen Daten erhoben werden, können Auskunfts- und Löschersuchen mangels vorhandener Daten regelmäßig nur negativ beschieden werden.

## 11. Kinder

Die Anwendung richtet sich an medizinisches Fachpersonal und Auszubildende in der Kardiotechnik. Sie ist nicht für Kinder bestimmt und erhebt keine Daten von Kindern.

## 12. Kein Medizinprodukt

PerfusionCalc ist ein Werkzeug für Ausbildung und persönliche Nutzung. Es ist **kein Medizinprodukt** im Sinne der Verordnung (EU) 2017/745 (MDR), ist nicht für die klinische Anwendung validiert und darf nicht als Grundlage für Diagnose, Therapieentscheidung oder Patientenbehandlung dienen. Ergebnisse sind stets gegen die Primärliteratur und die Vorgaben der eigenen Einrichtung zu prüfen.

## 13. Änderungen

Änderungen dieser Erklärung werden unter der oben genannten URL veröffentlicht. Maßgeblich ist die dort abrufbare Fassung mit dem jeweils aktuellen Datum.

---

# English

## 1. Controller

Nils Röder

E-mail: perfusioncalc@unbox.at

## 2. Summary

**PerfusionCalc collects no personal data.** There is no sign-up, no user account, no analytics, no tracking, no advertising, no advertising identifiers, no crash-reporting service and no sharing with third parties. All calculations run entirely on the device.

## 3. Patient and measurement values you enter

Every value entered into the app (height, weight, Hb/Hct, blood gases, electrolytes, flow rates, cardioplegia parameters and so on) is held **in memory only**. It is never written to storage, never included in a backup and never transmitted. Closing the app or reloading the web page discards it.

One exception: if you use the export function to produce a PDF, that file contains the values you entered. It is created locally, at a location you choose. From that point the file is your responsibility — particularly if it relates to an identifiable patient.

## 4. Settings stored locally

Only application settings are written to device storage (Android/iOS: `SharedPreferences`; web: `localStorage`):

| Stored | Purpose |
|---|---|
| Language (DE/EN) | interface language across restarts |
| Theme (light/dark/system) | appearance |
| Cardioplegia alarm settings (interval, sound, vibration, repeat) | reminder feature |
| del Nido mixing ratio | last protocol used |

None of these contain personal data. They are removed completely by uninstalling the app or clearing site data in the browser.

The Android app is explicitly excluded from Google cloud backup and from device-to-device transfer (`android:allowBackup="false"`, `data_extraction_rules.xml`), so these settings do not leave the device either.

## 5. Android permissions

| Permission | Purpose |
|---|---|
| `POST_NOTIFICATIONS` | display the cardioplegia re-dose reminder |
| `SCHEDULE_EXACT_ALARM` | fire that reminder on time |
| `RECEIVE_BOOT_COMPLETED` | restore pending reminders after a restart |
| `WAKE_LOCK` | wake the screen when a reminder fires |
| `VIBRATE` | optional vibration |

The reminder is optional and is scheduled locally on the device. There is no push service and no server.

**The release build of the Android app declares no `INTERNET` permission,** which makes data transmission technically impossible. This is verifiable in the manifest of the published build.

## 6. Web app (perfusioncalc.de)

The web app is served as a static site via GitHub Pages (GitHub, Inc., 88 Colin P. Kelly Jr. Street, San Francisco, CA 94107, USA). As hosting provider, GitHub processes technically necessary connection data in server log files — IP address, timestamp, requested resource and user agent. This processing is outside our control and is unavoidable for the delivery of any web page. The legal basis is Art. 6(1)(f) GDPR (legitimate interest in technical operation). Details: [GitHub Privacy Statement](https://docs.github.com/site-policy/privacy-policies/github-privacy-statement) and [GitHub Pages Data Collection](https://docs.github.com/pages/getting-started-with-github-pages/about-github-pages#data-collection).

The application itself loads **no** external resources: no CDNs, no third-party fonts, no analytics scripts, no cookies. The typeface used (Roboto, Apache-2.0) has been bundled with the program since version 0.4.3 and is not fetched from a Google server. A service worker caches the program files in the browser so the app works offline; no entered data is cached.

When the reminder feature is enabled, the browser asks for notification permission. It is granted locally and evaluated locally.

## 7. Offline Windows distribution

The Windows bundle contains the web app and a local web server (Caddy) bound to `localhost` only. No outbound connection is made.

## 8. Recipients, third countries, automated decisions

No data is shared with third parties, except for the technically unavoidable processing by the hosting provider described in section 6. There is no automated decision-making and no profiling.

## 9. Retention

As no data is collected, no retention period applies. Local settings remain on your device until you uninstall the app or clear site data.

## 10. Your rights

You have the rights set out in Art. 15–21 GDPR (access, rectification, erasure, restriction, portability, objection) and the right to lodge a complaint with a supervisory authority under Art. 77 GDPR. Because no personal data is collected, access and erasure requests will normally have to be answered in the negative for want of any data held.

## 11. Children

The application is aimed at clinical perfusion professionals and students. It is not directed at children and collects no data from children.

## 12. Not a medical device

PerfusionCalc is a tool for education and personal use. It is **not a medical device** within the meaning of Regulation (EU) 2017/745 (MDR), is not validated for clinical use, and must not be relied upon for diagnosis, treatment decisions or patient management. Results must always be verified against the primary literature and your institution's own protocols.

## 13. Changes

Changes to this policy are published at the URL above. The version available there, bearing the current date, is the authoritative one.
