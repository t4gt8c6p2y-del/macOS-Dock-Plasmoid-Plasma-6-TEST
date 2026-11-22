# macOS Dock Plasmoid für KDE Plasma 6

[English](README.md) | **Deutsch** | [Français](README.fr.md)

Ein eigenständiges Plasma-6-Dock im macOS-Stil mit Vergrößerung, Taskmanager,
Fenstersteuerung und einem zum Qt-Farbschema passenden Blur-Hintergrund.

## Funktionen

- flüssige macOS-artige Vergrößerung beim Überfahren der Symbole
- detaillierte Animationseinstellungen für Reaktion und Dämpfung der
  Vergrößerung, Klick- und Start-Sprunghöhe, Ein-/Ausblenddauer des Docks,
  Gruppen-Popup-Federung und Ordner-Hover-Vergrößerung
- Verschieben und Anordnen der Starter per Drag-and-Drop mit der Maus
- App-Gruppen im Android-Stil: Eine App mittig auf einer anderen ablegen, um
  sie zu gruppieren; Raster oder Liste dienen zum Starten, Umbenennen,
  Entfernen einzelner Apps oder Auflösen der Gruppe; angeheftete Starter
  funktionieren unabhängig davon, ob ihre App geöffnet oder geschlossen ist,
  einschließlich der Zuordnung von Wine-/Proton-`.exe`-Fenstern
- optionale Download-/Ordnerstapel mit macOS-artiger Dateiansicht; weitere
  Ordner lassen sich direkt aus dem Dateimanager auf das Dock ziehen; Liste,
  Raster oder Fächer werden in den Dock-Einstellungen ausgewählt
- optionale Fortschrittsringe für Plasma-Aufträge und Unity-kompatible
  Downloads auf Anwendungssymbolen und passenden Ordnerstapeln
- optionale KDE-Connect-Badges für kürzlich empfangene Links und Dateien;
  Links werden dem Standardbrowser des Systems zugeordnet
- optionaler, designkonformer Papierkorb mit Leer-/Vollstatus und Dateiablage
- optionales Energie-/Sitzungsmenü mit systemabhängig verfügbaren Aktionen für
  Energiesparmodus, Neustart, Herunterfahren, Bildschirmsperre und Abmeldung
- optionaler Desktopumschalter links oder rechts mit Zahlen oder den in Plasma
  festgelegten Desktopnamen sowie einer dauerhaften Schaltfläche für weitere Desktops
- interaktive Live-Fenstervorschauen mit Aktivieren und Schließen einzelner Fenster
- Launcher und laufende Anwendungen in einem gemeinsamen Taskmanager
- Kontextmenü zum Öffnen neuer Fenster sowie zum Minimieren, Maximieren,
  Wiederherstellen und Schließen einzelner oder gruppierter Fenster
- sichere KWin-Fensterauswahl zum sofortigen Beenden nicht reagierender Fenster
- automatisches Ausblenden bei maximierten Fenstern
- vollbildsichere Ebenen und erzwungenes Ausblenden bei Mediaplayern wie mpv
  und Dragon Player
- einstellbare Platzierung unten, links oder rechts, immer mittig am Rand
- animiertes Ein- und Ausfahren an allen unterstützten Bildschirmkanten
- Hintergrund, Rahmen und Aktivitätsanzeigen aus der Qt-Systempalette
- Theme- oder eigene Hintergrundfarbe sowie einstellbare Rundung, Rahmen,
  Schatten, Glanzlicht und Blur
- präzise, abgerundete Blur-Region ohne rechteckigen Hover-Hintergrund
- vollständige deutsche, US-englische und französische Oberfläche nach Systemsprache

## Spotlight und Siri KI

- **Spotlight**: eine Leiste „Suchen oder fragen“ mit Ergebnisfeld nach dem Vorbild von macOS 27, geöffnet mit der Windows-Taste, Alt+Leertaste, durch Tippen auf dem Desktop oder über das Dock-Symbol. Der Glashintergrund folgt den Liquid-Glass-Einstellungen. Die Schaltfläche links in der Leiste wechselt zwischen *Standard* (Apps, dann KI) → *Apps* → *Dateien* → *Zwischenablage*; ein Doppelklick führt zurück zum Standard. Eine Kategorie Favoriten (Stern) ist vorhanden.
- **Siri KI**: eine Chat-App mit Unterhaltungsverlauf (Gemini, GLM über OpenCode oder jeder OpenAI-kompatible Dienst).
- **Zugangsdaten**: nur in der lokalen Plasma-Konfiguration (`~/.config`) gespeichert, nie im Repository und von „Stil kopieren“ ausgenommen. Eingabe in den Einstellungen im Reiter *Zugangsdaten*.
- `install.sh` kopiert `spotlight-integration.sh` nach `~/.local/share/macosdock/` und führt es aus: Die Windows-Taste öffnet Spotlight, KRunner wird maskiert. Rückgängig: `~/.local/share/macosdock/spotlight-integration.sh disable`, oder den Schritt mit `MACOSDOCK_SKIP_SPOTLIGHT=1 ./install.sh` überspringen. Einmal ab- und wieder anmelden.
- Das kostenlose GLM-Modell ist nur über den Befehl `opencode` (opencode.ai) erreichbar; Gemini braucht einen kostenlosen Schlüssel von aistudio.google.com/apikey.

### Anhänge und Screenshots

- **Anhänge**: In der Siri-KI-App und im Unterhaltungsfenster von Spotlight fügt `Strg+V` ein Bild oder Dateien an (kopiert aus einem Screenshot, einem Browser oder dem Dateimanager); auch über die Schaltfläche `+` lassen sie sich auswählen. Ein Bild erscheint als Vorschau, jede andere Datei mit einem Symbol ihres Typs (PDF, Word, Tabelle …). Ein Bild kann ganz ohne Text gesendet werden, und ein Klick auf ein Bild in der Unterhaltung öffnet es in voller Größe (zum Schließen daneben klicken, das Kreuz oder `Esc`). Bilder gehen an Gemini und OpenAI-kompatible Dienste; der Befehl `opencode` erhält nur Text.
- **Screenshot → Siri fragen**: Das Plasmoid hat eine eigene Aufnahmeoberfläche mit einer einzigen Schaltfläche **Siri fragen** statt der Anmerkungsleiste von Spectacle (diese Leiste gehört zu Spectacle und lässt sich vom Plasmoid weder ändern noch ausblenden). Einen Bereich aufziehen (`Eingabe` nimmt den ganzen Bildschirm, `Esc` bricht ab) und auf **Siri fragen** klicken: Das Unterhaltungsfenster von Spotlight öffnet sich mit dem Bild über der Schreibleiste, bereit zum Senden mit oder ohne Text.
- **Aufnahme starten**: Rechtsklick auf die Schaltfläche `+` im Unterhaltungsfenster von Spotlight, dann *Screenshot für Siri…*; oder ein Tastenkürzel mit diesem Befehl belegen (Systemeinstellungen → Tastatur → Kurzbefehle → Neu hinzufügen → Befehl oder Skript):

  ```bash
  dbus-send --session --type=method_call --dest=org.macosdock.Spotlight /Spotlight org.macosdock.Spotlight.screenshot
  ```

  Um dafür die gewohnte Screenshot-Taste (zum Beispiel `Druck`) zu verwenden, diese Taste zuerst beim Eintrag *Spectacle* in denselben Kurzbefehl-Einstellungen entfernen und dann dem Befehl oben zuweisen.
- **Voraussetzung**: [Spectacle](https://apps.kde.org/de/spectacle/) muss installiert bleiben: Es nimmt das Bild im Hintergrund auf, ohne seine Oberfläche zu zeigen, weil ein Plasmoid unter Wayland den Bildschirm nicht selbst lesen kann.

## Voraussetzungen

- KDE Plasma 6
- Qt 6 mit Qt Quick/QML
- KDE Frameworks 6 WindowSystem, Service, Solid, I18n und KIO
- CMake und ein C++17-Compiler
- Gettext (`msgfmt`) für die Übersetzungskataloge

KDE Connect ist optional. Wenn es nicht installiert ist oder nicht läuft,
bleibt die Integration für kürzlich geteilte Elemente ohne Auswirkungen auf
das Dock inaktiv.

Unter Arch Linux werden die Build-Abhängigkeiten beispielsweise mit folgendem
Befehl installiert:

```bash
sudo pacman -S --needed base-devel cmake gettext qt6-declarative qt6-shadertools kservice kwindowsystem solid ki18n kio
```

## Installation

```bash
git clone https://github.com/DomiLuebben/macOS-Dock-Plasmoid-Plasma-6.git
cd macOS-Dock-Plasmoid-Plasma-6
./install.sh
systemctl --user restart plasma-plasmashell.service
```

Das Installationsskript baut zuerst das kleine native QML-Modul für die
Blur-Region, die KWin-Fensteraktionen und die optionalen Integrationen und
installiert bzw. aktualisiert anschließend das Plasmoid.

Bei „Anwendung sofort beenden …“ wird der Mauszeiger zur Zielauswahl. Klicke das
nicht reagierende Fenster an oder brich mit `Esc` ab.

Füge **macOS Dock Task Manager** über „Miniprogramme hinzufügen“ direkt zur
Arbeitsfläche hinzu. Er gehört nicht in eine Plasma-Leiste: Das unsichtbare,
minimale Desktop-Plasmoid speichert nur die Einstellungen, während das Dock in
einem eigenen transparenten Fenster läuft. In den Einstellungen kannst du
unten, links oder rechts wählen; am ausgewählten Bildschirmrand bleibt das
Dock immer mittig ausgerichtet.

Zum Erstellen einer App-Gruppe ziehst du eine App mittig auf eine andere. Das
Ziel vergrößert sich sofort; beim Loslassen entsteht die Gruppe. Das Ablegen
zwischen zwei Symbolen ordnet das Dock weiterhin nur neu. Gruppierte Apps
behalten Plasmas natives Verhalten für laufende Tasks und Minimieranimationen.
Besitzt eine gruppierte App mehrere Fenster, öffnet ihr Eintrag eine
verschachtelte Fensterauswahl, statt ein beliebiges Fenster zu minimieren.
Android-artiges Raster oder kompakte Liste lassen sich in den
Dock-Einstellungen auswählen.

Wenn du von einer älteren Version aktualisierst, entferne das Dock zuerst aus
der bisherigen Plasma-Leiste. Falls diese Leiste ausschließlich für das Dock
angelegt wurde, entferne die ganze Leiste. Füge das Miniprogramm anschließend
direkt zur Arbeitsfläche hinzu.

## Minimieranimation wie unter macOS

Für dieselbe Fensterminimierung wie unter macOS öffne **Systemeinstellungen → Animationen**, wähle für das **Minimieren von Fenstern** den Effekt **Magische Lampe** und stelle die **Animationsdauer** auf **150 ms**.

## Lizenz

GPL-2.0-or-later
