# Play Console — Data safety, Abgleich mit der Datenschutzerklärung

**Stand:** v0.4.18+40 · geprüft gegen `privacy_policy.md`, `web/privacy.html`,
`pubspec.yaml` und das Release-Manifest.

Ausfüllhilfe für *Play Console → App-Inhalte → Datensicherheit*. Für jede
Antwort steht dabei, worauf sie sich stützt — Abweichungen zwischen Formular
und Datenschutzerklärung sind in dieser Kategorie der häufigste
Ablehnungsgrund.

> Ich bin kein Anwalt und die Play-Console-Oberfläche ändert sich. Die
> Antworten unten folgen der aktuellen Google-Definition von „erheben"; die
> Feldbezeichnungen können in Details abweichen.

---

## 1. Die entscheidende Definition

Google definiert **„erheben" (collect) als: Daten verlassen das Gerät.**
Nicht: Daten werden verarbeitet. Nicht: Daten werden gespeichert.

Daraus folgt für PerfusionCalc alles Weitere:

| Was die App tut | Verlässt das Gerät? | Im Formular anzugeben? |
|---|---|---|
| Patientenwerte im Arbeitsspeicher berechnen | nein | **nein** |
| Spracheinstellung, Design, Alarmparameter, del-Nido-Verhältnis, EK-Hkt in `SharedPreferences` | nein | **nein** |
| PDF über den System-Speichern-Dialog ablegen | nein — der Nutzer wählt das Ziel, die App liest die Datei nie wieder | **nein** |
| Lokale Benachrichtigung planen | nein | **nein** |

Der stärkste Beleg steht im Manifest: **der Release-Build deklariert keine
`INTERNET`-Berechtigung.** Die deklarierten Berechtigungen sind
`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `VIBRATE`, `WAKE_LOCK`,
`RECEIVE_BOOT_COMPLETED` — keine davon erlaubt Netzwerkzugriff. Eine App ohne
`INTERNET` kann technisch nichts übertragen.

---

## 2. Antworten Feld für Feld

### Datenerhebung und -sicherheit

| Frage | Antwort | Begründung |
|---|---|---|
| Erhebt oder teilt deine App die erforderlichen Nutzerdatentypen? | **Nein** | siehe oben; keine `INTERNET`-Berechtigung im Release-Build |

Mit „Nein" entfallen die Folgefragen zu Datentypen, Zwecken, Verschlüsselung
bei der Übertragung und Löschmechanismus. Sie erscheinen nur, wenn eine
Erhebung bejaht wurde. Das Formular ist **trotzdem Pflicht** — es gibt kein
Überspringen für Apps ohne Datenerhebung.

### Falls das Formular die Fragen dennoch anzeigt

| Frage | Antwort |
|---|---|
| Werden alle erhobenen Daten bei der Übertragung verschlüsselt? | **nicht zutreffend** (es wird nichts übertragen) |
| Können Nutzer die Löschung ihrer Daten beantragen? | **nicht zutreffend** — Deinstallation entfernt alles; ein Löschmechanismus setzt serverseitige Daten voraus, die es nicht gibt |
| Ist die Datenerhebung unabhängig gegen einen Sicherheitsstandard geprüft? | **Nein** (optionale Angabe) |

### Angrenzende Abschnitte unter „App-Inhalte"

| Abschnitt | Antwort | Begründung |
|---|---|---|
| Datenschutzerklärung (URL) | `https://perfusioncalc.de/privacy.html` | seit v0.4.1 erreichbar, zweisprachig |
| Werbe-ID | **Nein** | keine Werbe-SDKs, keine `AD_ID`-Berechtigung |
| Werbung | **Die App enthält keine Werbung** | |
| App-Zugriff | **Alle Funktionen ohne besonderen Zugang verfügbar** | kein Login, kein Konto |
| Zielgruppe | **ausschließlich 18+** | Fachanwendung für Kardiotechnik; nicht als kinderorientiert einstufen |
| Nachrichten-App | **Nein** | |
| Regierungs-App, Finanzfunktionen | **Nein** | |
| Gesundheits-App-Deklaration | **prüfen** — siehe unten |

---

## 3. Drei Punkte, die eine bewusste Entscheidung brauchen

### 3.1 Store-Kategorie: Bildung — entschieden

**Kategorie: *Bildung*, nicht *Medizin*.**

Die Kategorie *Medizin* zieht in mehreren Regionen Nachfragen zum
Medizinprodukte-Status nach sich, und PerfusionCalc schließt diesen Status
ausdrücklich aus (Abschnitt 12 der Datenschutzerklärung: **kein
Medizinprodukt im Sinne der Verordnung (EU) 2017/745**, nicht für die
klinische Anwendung validiert). Eine Kategorie zu wählen, die genau die
Prüfung auslöst, deren Ergebnis man vorab verneint, schafft Aufwand ohne
Gegenwert.

*Bildung* deckt den erklärten Zweck — Ausbildung und persönliche Nutzung in
der Kardiotechnik — und ist damit keine Ausweichbewegung, sondern die
zutreffendere Einordnung.

**Damit die Wahl trägt, muss der Store-Text zu ihr passen.** Das ist der
eigentliche Punkt: Die Kategorie ist eine Zeile im Formular, gelesen wird die
Beschreibung.

| gehört hinein | gehört nicht hinein |
|---|---|
| „für Ausbildung und Fortbildung in der Kardiotechnik" | „für den klinischen Einsatz" |
| „Nachschlagewerk und Rechenhilfe" | „zur Therapieentscheidung" |
| „Ergebnisse sind gegen die Primärliteratur und die Vorgaben der eigenen Einrichtung zu prüfen" | „validiert", „zertifiziert", „geprüft" |
| der MDR-Ausschluss wörtlich | Aussagen über Patientensicherheit oder Behandlungsqualität |

Der MDR-Ausschluss gehört **wörtlich in die Store-Beschreibung**, nicht nur
in die Datenschutzerklärung. Eine Kardiotechnik-Rechen-App ohne diesen
Hinweis im Listing lädt genau die Nachfrage ein, die sie vermeiden will.

**Die Gesundheits-Deklaration hängt an der Funktion, nicht an der
Kategorie.** Falls Play sie abfragt, ist sie wahrheitsgemäß auszufüllen —
*Bildung* befreit nicht davon. Was die Kategorie ändert, ist die
Wahrscheinlichkeit, dass die Prüfung überhaupt in die Medizinprodukt-Schiene
läuft.

### 3.2 Die Web-App gehört **nicht** ins Formular

`perfusioncalc.de` läuft über GitHub Pages, und GitHub verarbeitet dabei
IP-Adresse, Zeitpunkt und User-Agent in Server-Logfiles — Abschnitt 6 der
Datenschutzerklärung sagt das ausdrücklich.

Das ist **kein Widerspruch** zum „Nein" im Formular: Die Datensicherheits-
Erklärung gilt für die über Play ausgelieferte Android-App, nicht für eine
Website. Wer beides vermischt, deklariert eine Erhebung, die die App gar
nicht vornehmen kann.

Falls die Play-Prüfung darauf zurückkommt, ist die Antwort genau diese
Trennung — und die Datenschutzerklärung belegt sie, weil sie beide Fälle
getrennt behandelt.

### 3.3 SDK-Prüfung: erledigt, aber nachvollziehbar halten

Google rechnet Daten, die ein eingebundenes SDK überträgt, der App zu.
Vollständige Liste der Laufzeitabhängigkeiten:

| Paket | Überträgt Daten? |
|---|---|
| `shared_preferences` | nein — Gerätespeicher |
| `flutter_local_notifications` | nein — lokale Planung, kein Push-Dienst |
| `timezone` | nein — mitgelieferte Zonendatenbank |
| `pdf` | nein — erzeugt Bytes im Speicher |
| `file_picker` | nein — System-Dialog, Ziel wählt der Nutzer |
| `web` | nein — Interop-Bindings, nur im Web-Build aktiv |

Kein Analytics, kein Crashlytics, kein Firebase, keine Werbe-SDKs.

Absturzberichte, die Google Play selbst über Android Vitals sammelt, sind
Googles eigene Erhebung und nicht die der App.

**Hier ist nichts zu entscheiden — es ist eine Pflicht mit Verfallsdatum.**
Das „Nein" im Formular gilt für den Stand dieser Liste. Kommt später eine
Abhängigkeit dazu, die Daten überträgt, wird die Angabe falsch, ohne dass
irgendjemand etwas Falsches getan hätte.

Deshalb prüft `tool/verify/consistency_check.py` diese Tabelle jetzt
mechanisch gegen `pubspec.yaml`: Jede Laufzeitabhängigkeit muss hier
aufgeführt sein, sonst schlägt die Prüfung fehl — lokal und in der CI. Ein
neues Paket zwingt damit zu einer bewussten Zeile in dieser Tabelle, statt
auf ein Erinnern zu bauen.

Was dann zu tun ist: In der Dokumentation des Pakets nachsehen, ob es Daten
vom Gerät sendet, die Zeile mit „nein" oder „ja — was genau" ergänzen, und
bei „ja" das Formular anpassen.

---

## 4. Konsistenzprüfung: Formular gegen Datenschutzerklärung

Jede Zeile ist eine Aussage, die in beiden Dokumenten übereinstimmen muss.

| Aussage im Formular | Deckung in der Datenschutzerklärung |
|---|---|
| Keine Datenerhebung | Abschnitt 2: „erhebt keine personenbezogenen Daten"; Abschnitt 3: Werte nur im Arbeitsspeicher |
| Keine Weitergabe an Dritte | Abschnitt 8 |
| Keine Werbe-IDs | Abschnitt 2 |
| Kein Konto, kein Login | Abschnitt 2 („keine Registrierung, kein Nutzerkonto") |
| Kein Löschmechanismus nötig | Abschnitt 9 (keine Speicherdauer) und 10 (Auskunftsersuchen mangels Daten negativ) |
| Lokale Einstellungen ohne Personenbezug | Abschnitt 4 mit vollständiger Tabelle |
| Kein Cloud-Backup, keine Geräteübertragung | Abschnitt 4, belegt durch `allowBackup="false"` und `data_extraction_rules.xml` |
| Nicht für Kinder | Abschnitt 11 |

**Wenn sich eine dieser Aussagen ändert, müssen drei Dinge gemeinsam
wandern:** `privacy_policy.md`, `web/privacy.html` und das Formular. Die
ersten beiden prüft `tool/verify/consistency_check.py` gegeneinander; das
Formular kann kein Skript erreichen.

---

## 5. Reihenfolge

1. `web/privacy.html` deployen und im Browser öffnen — die URL muss
   erreichbar sein, **bevor** sie im Formular eingetragen wird.
2. Datenschutz-URL unter *App-Inhalte* eintragen.
3. Datensicherheits-Formular ausfüllen: Hauptfrage **Nein**, absenden.
4. Werbe-ID, Werbung, App-Zugriff, Zielgruppe beantworten.
5. Kategorie **Bildung** wählen und die Store-Beschreibung an der Tabelle in
   Abschnitt 3.1 ausrichten — inklusive MDR-Hinweis im Fließtext.
6. Vorschau der Datensicherheits-Karte ansehen — dort steht dann sinngemäß
   „Keine Daten werden erfasst" und „Keine Daten werden geteilt". Genau das
   soll auf der Store-Seite stehen.
