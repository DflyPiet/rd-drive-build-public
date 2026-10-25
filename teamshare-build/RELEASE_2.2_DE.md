# Radio Diabolus TeamShare 2.2.0

## Tatsächlich integriert

- Branding Radio Diabolus mit hochgeladenem Icon und dunkler Oberfläche
- Offline einsehbares Impressum in der Form „Radio Diabolus · www.radio-diabolus.rocks“; die vollständige Anbieterkennzeichnung ist auf https://radio-diabolus.dk/site/about-us/ verlinkt
- Eine eigens verfasste, deutsch- und englischsprachige Datenschutzerklärung zum aktuellen Desktop-Client mit Angaben zu lokalen Identitäten, Peers, IP-Adressen, Dateiübertragung, Löschung und Datenschutzrechten
- Entfernt: eigenständige Zeilen „Support“, „Quellcode“ und „Sicherheitslücke melden“ in der Ansicht „Über TeamShare“
- Die Lizenz heißt in der Oberfläche „Radio Diabolus: Lizenzhinweise“, bewahrt aber korrekt die Originalrechte und GNU AGPL-3.0-or-later. Originalquellen und Patch werden weiter mitgeliefert.
- Lokaler Audio-Check und optionale Teamraum-Vorlagen aus 2.1
- NEU: freiwillige lokale PCM-Stichprobenmessung für Abtastrate, Kanäle, Sample-Peak, RMS, ungefähren Anteil sehr leiser und fast voll ausgesteuerter Samples für Audiodateien bis 48 MB. Nicht LUFS, True Peak oder verbindliche Clipping-Messung
- Windows-Installer mit Deinstallation und portable ZIP
- Build-Gates: Linux-Unit- und Invariantentests; vier gezielte Windows-Integrationstests (38 Tests), TypeScript, ESLint und Paketerstellung. Für produktiven Teamrollout zusätzlich manuelle Tests erforderlich

## Offene Anforderungen

Folgende umfangreiche Vorschläge sind nicht als fertige Funktionen ausgegeben:
- Audio-Vorschau unmittelbar aus entfernten P2P-Dateilisten, automatisierte echte EBU-R128-/True-Peak-Analyse
- Remote synchronisierter Musikbemusterungs-Eingang, Release-Kalender, redaktioneller Status, Dublettenprüfung und Suchindex
- Import in RadioBOSS und automatisch erzeugtes Sendungsarchiv
- Bandbreitenprofile für Live-Sendungen und komplexe Transferprioritäten
- Berechtigungsrollen mit Ende-zu-Ende-Kontrolle, vollständige Schlüsselrotation und sicherer Headless-Dienst
- Automatische signierte Updates, Digitalzertifikat für Windows, eigene Downloadseite oder ein dauerhaftes GitHub-Release

Die ursprüngliche Mirall-Dateiübertragung und deren Kryptographie wurden nicht umgeschrieben. Bis zur vollständigen Schlüsselrotation müssen bestehende Mitglieder und bereits heruntergeladene Kopien bei Zugriffsentzug gesondert berücksichtigt werden.

## Rechtliches

Vor produktiver Veröffentlichung sind Impressum und Datenschutzerklärung anhand der tatsächlichen Verantwortlichkeit, eingesetzten Infrastruktur und Teamverträge juristisch zu prüfen. Die originalen Lizenz- und Urheberrechtshinweise bleiben erhalten. „Radio Diabolus“-Branding begründet keine exklusiven Rechte am ursprünglichen Mirall-Code.

## Installation und Prüfung

Installer: Radio-Diabolus-TeamShare-2.2.0-Setup-x64.exe. Alternativ portable ZIP vollständig entpacken. Die Installer-Datei ist unsigniert.

Die SHA256SUMS.txt aus dem Release-Artifakt dient zur Überprüfung. Ein erfolgreicher GitHub-Build ersetzt keine Abnahme auf zwei echten Windows-Rechnern. Jede neue Ausgabe muss separat installiert werden, automatische Updates sind deaktiviert.
