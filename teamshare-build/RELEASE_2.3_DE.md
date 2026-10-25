# Radio Diabolus TeamShare 2.3.0

## Enthalten

- Radio-Diabolus-Branding und Icon
- Sichtbare Links Datenschutzerklärung, Impressum, Lizenzhinweise entfernt
- Feedback-Schaltfläche in der Topbar, Feedback- und Anleitungseinträge im Profil und nativen Hilfemenü entfernt
- Die externe Anleitungskarte in der Raumübersicht entfernt
- Lizenztexte, AGPL-Urhebernachweise und Quellcode bleiben im ausgelieferten Paket
- Lokale Bemusterungsverwaltung (IndexedDB), Interpret, Titel, Album, Label, Veröffentlichungsdatum, Notizen und Status, Suche/Filter
- CSV-Export und RadioBOSS-kompatibler M3U8-Playlistenexport freigegebener lokaler Windows-Audiodateien
- Audio-Check mit optionaler lokaler PCM-Stichprobenanalyse, bestehende Raumvorlagen
- Ursprüngliches Mirall-Protokoll und Verschlüsselung unverändert
- Windows-Setup (unsigniert) und portable ZIP mit CI-Tests

## Grenzen und offene Anforderungen

- RadioBOSS-Integration: funktionierender M3U8-Dateiexport zum manuellen Import. Keine aktive Steuerung oder Synchronisierung der RadioBOSS-Mediathek.
- Musikdatenbank: lokal je Computer. Kein teamweiter Metadatenabgleich, keine ID3-Erkennung und keine zentrale Rechteverwaltung.
- Kryptographisch differenzierte Teamrollen fehlen. Bestehende kryptographisch geschützte Mirall-Raummitgliedschaft ist keine granulare Admin-/Moderator-/Gast-Rollenverwaltung. Keine bloße UI-Scheinberechtigung wurde eingeführt.
- Mirall-Schlüsselrotation nach dem Entfernen eines Mitglieds ist noch offen: https://github.com/ok/mirall/issues/395
- Automatische Updates sind deaktiviert (UPGRADE_KEY=none). Ein unabhängiger signierter Updatekanal erfordert private Signaturschlüssel, Release-Infrastruktur und zusätzliche Sicherheitsprüfungen.

## Rechtliches

Radio Diabolus veröffentlicht die Änderungen. Mirall von Oliver Kohl (Zsapping Software) bleibt AGPL-3.0-or-later. Lizenztext, Originalquelle und Anpassungspatch sind im Paket vorhanden. Entfernen eines Oberflächenlinks hebt die AGPL-Pflichten nicht auf. Eine Datenschutzerklärung ist als Quelldokument vorhanden. Notwendige externe Informationspflichten sind vor dem Teamrollout zu prüfen.

## Installation

Das GitHub-Actions-Artefakt herunterladen. Entweder Radio-Diabolus-TeamShare-2.3.0-Setup-x64.exe ausführen oder die portable ZIP komplett entpacken. SHA256SUMS.txt verifizieren.

Die neue lokale Bemusterungsdatenbank liegt in IndexedDB der Anwendung und wird durch das Mirall-Schlüsselbackup nicht automatisch gesichert. Regelmäßig die angebotene CSV-Sicherung exportieren.

Vor Produktiveinsatz auf zwei Windows-Geräten die Freigaben, Installer-Upgrades, CSV/M3U8-Export und die Profileinstellungen testen.
