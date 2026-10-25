# Radio Diabolus TeamShare 2.1: Funktionsstand

Basis: Mirall 1.13.0, gepinnt auf Commit 9f5ae55a5b7c967d1a6dbd6e52a56a7acd5aa907. Ursprüngliche AGPL-3.0-or-later bleibt erhalten.

## Tatsächlich umgesetzt

- Radio-Diabolus-Branding mit Originalicon und dunklem Theme.
- Separater Audio-Check für lokal ausgewählte MP3, FLAC, WAV, OGG, AAC und M4A, mit lokaler Wiedergabe und Playlist. Unterstützte Codecs hängen von Electron ab. Die Dateiauswahl sendet keine Daten ins Netz.
- Fünf optionale Vorlagen für Teamräume. Ein Raum wird nur durch explizites Anklicken erstellt; bestehende Räume werden nicht verdoppelt.
- Windows-Installer mit Deinstallation sowie portable Version. Beide sind derzeit **unsigniert**.
- Strengerer Windows-Build: Unit-Tests und Peer-to-Peer-Tests müssen bestehen; SHA256-Datei wird erstellt. Bei Fehlern wird keine neue Version freigegeben.
- Backup, Benachrichtigungen und Netzwerkdiagnose werden aus Mirall unverändert übernommen. Teammitglieder müssen Backups im Client einrichten.

## Noch NICHT umgesetzt

- Audio-Wiedergabe direkt aus einer fremden Raum-Dateiliste: Im Audio-Check wählt man eine bereits lokal vorhandene Datei. Für direkte Streams wären eine autorisierte Dateischnittstelle und weitere Tests nötig.
- Individuelle, kryptographisch erzwungene Rollen Admin/Moderator/Gast. Ein bloßes Dropdown ohne Protokollschutz wäre unsicher.
- Vollständige Schlüsselrotation nach Mitgliederausschluss: Mirall verfolgt das upstream unter https://github.com/ok/mirall/issues/395 .
- Ein eigener Peer-to-Peer-Updatekanal mit signierten Releases. Er benötigt eine Herausgeberidentität sowie gesicherte Veröffentlichungsinfrastruktur.
- Digitales Codesigning des Installers. Dafür wird ein Zertifikat benötigt.
- Ständig erreichbarer Teamrechner als Windows-Dienst: Mirall arbeitet bislang hauptsächlich als GUI-App. Ein ständig laufender eingeloggter Desktop-PC kann vorhandene Dateien weiterhin bereitstellen. Ein echter Headless-Dienst ist ein eigenständiges Projekt (https://github.com/ok/mirall/issues/407).
- Eigene Radio-Diabolus-Downloadseite: Domain-Deployment und Freigabe der Veröffentlichung stehen aus.

## Installation

Die portable ZIP vollständig entpacken und die EXE im ausgepackten Ordner starten. Die Setup-EXE bietet eine normale Installation im Benutzerprofil. Die Setupdatei ist nicht digital signiert und sollte ausschließlich über vertrauenswürdige Quellen sowie SHA256-Prüfsumme verteilt werden.

## Datenschutz und Lizenz

Der Audio-Check liest nur vom Benutzer explizit ausgewählte Dateien, erzeugt temporäre Blob-URLs im lokalen Renderer und gibt diese wieder frei. Der Quellcode des Forks und die Änderungen werden zusammen mit dem Build ausgeliefert.

## Testkriterien vor Teamrollout

Auf zwei echten Windows-PCs Einladungen/Freigaben, große Dateitransfers, Unterbrechung/Fortsetzung, Recovery eines Backups, Autostart und Installer-Upgrade prüfen. Ergebnisse dokumentieren und erst dann produktive Verteilung.
