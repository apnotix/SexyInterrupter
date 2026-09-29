<div align="center">

# 🔥 SexyInterrupter

**Zauber unterbrechen. Kicks teilen. Nie wieder „Wer ist dran?“**
Ein schlanker Unterbrechungs-Koordinator: Das Addon erkennt, wer in deiner Gruppe oder deinem Schlachtzug unterbrechen kann, zeigt die Abklingzeiten aller Spieler live an und meldet dir genau dann „Jetzt unterbrechen!“, wenn du an der Reihe bist. Alles frei einstellbar im Edit Mode.

![WoW Forever](https://img.shields.io/badge/WoW-Forever-e8c26a?style=for-the-badge)
![Retail](https://img.shields.io/badge/WoW-Retail-c8a24a?style=for-the-badge)
![Interface](https://img.shields.io/badge/Interface-120100%20%7C%2016001-3b2b12?style=for-the-badge)
![Edit Mode](https://img.shields.io/badge/Edit%20Mode-ja-4fc16a?style=for-the-badge)

[🇬🇧 English version](README.en.md)

</div>

---

Keine Tabellen, kein Chat-Spam, kein „Ich dachte, du machst das!“ – nur eine saubere Rotation auf deinem Bildschirm.

---

## ✨ Features

### 🎯 Intelligente Unterbrechungs-Rotation
- Baut automatisch eine **Kick-Reihenfolge** für die ganze Gruppe bzw. den Schlachtzug
- Sortiert nach **wer zuerst bereit ist**, danach nach Rollenpriorität (🛡️ Tank → ⚔️ Schaden → 💚 Heiler)
- Der nächste Spieler steht immer ganz oben

### 📣 „Jetzt unterbrechen!“-Hinweis
- Große Bildschirmmeldung mit dem **Namen deines Ziels**, sobald es zaubert und du an der Reihe bist
- Optionaler **Soundalarm** 🔔 (beliebiger Sound aus deiner SharedMedia-Bibliothek, mit Vorschau)
- Optionaler **Bildschirm-Flash** ⚡, damit du es nicht übersiehst
- Die Meldung verschwindet automatisch, wenn der Zauber endet oder du das Ziel wechselst

### 🧠 Lernt Unterbrechungen selbstständig
- Erkennt die Unterbrechung jedes Spielers, **sobald sie benutzt wird** – keine manuelle Einrichtung
- Unterstützt Spieler mit **mehreren Unterbrechungen** (jede bekommt eigene Zeile, eigenes Symbol und eigene Abklingzeit)
- Mit der Maus über das Zaubersymbol siehst du die genaue Fähigkeit
- Funktioniert für alle Klassen, auch 🐉 **Rufer (Quell)**

### 🔄 Gruppen-Synchronisation in Echtzeit
- Abklingzeiten werden unter allen Spielern mit dem Addon geteilt (Gruppe, Schlachtzug, Instanzgruppe)
- Rollen- und Spezialisierungswechsel werden sofort übertragen
- Spieler verschwinden nur, wenn sie **wirklich weg sind** – nicht bei jedem Ladebildschirm
- Spieler außerhalb der Reichweite werden **abgedunkelt** 👻, damit du siehst, wer das Ziel überhaupt erreicht

### 🎨 Vollständig konfigurierbar – direkt im Bearbeitungsmodus
Alles findest du im **Bearbeitungsmodus (Edit Mode)** von Blizzard: Fenster ziehen, direkt anpassen, mit Live-Vorschau.

| | |
|---|---|
| 📐 **Layout** | Fensterbreite, Balkenhöhe, maximale Zeilen, Wachstumsrichtung (oben / unten) |
| 🔤 **Schrift** | Schriftart, Größe und Farbe (mit Live-Vorschau der Schriften) |
| 🖼️ **Texturen** | Statusbalken-, Hintergrund- und Rahmentextur (über SharedMedia) |
| 🌈 **Farben** | Balken-, Hintergrund-, Rahmen- und Schriftfarbe, optional **Klassenfarben** |
| 🔔 **Benachrichtigung** | Meldung, Sound (mit Vorschau), Bildschirm-Flash |
| 💬 **Chat-Ansage** | Optional eigene Unterbrechungen in Sagen / Schreien / Gruppe / Schlachtzug ansagen |
| 👁️ **Sichtbarkeit** | Nur im Kampf anzeigen, Minimap-Symbol an/aus |

Einstellungen werden pro Profil gespeichert und überstehen `/reload` sowie Wechsel des Edit-Mode-Layouts.

### 🥇 Prioritätszuweisung
- Gruppenleiter können die **Priorität einzelner Spieler überschreiben**
- So legst du für knifflige Bosskämpfe genau fest, wer zuerst kickt

### 🧭 Extras
- 🗺️ **Minimap-Symbol** – Linksklick öffnet den Bearbeitungsmodus, Rechtsklick die Einstellungen
- 🌍 **Lokalisiert** auf Deutsch und Englisch
- 🪶 Schlank, keine zusätzlichen Abhängigkeiten (alle Bibliotheken sind enthalten)
- ✅ Ein Download für **Retail** und **World of Warcraft: Forever**

---

## 🚀 Los geht's

1. SexyInterrupter installieren – am besten haben auch deine Gruppenmitglieder das Addon
2. Einloggen – das Fenster erscheint, sobald du in einer Gruppe bist
3. **Bearbeitungsmodus** öffnen (`/si lock` oder Minimap-Symbol), um das Fenster zu verschieben und zu gestalten
4. Unterbrechen. 💥

## ⌨️ Chat-Befehle

| Befehl | Wirkung |
|---|---|
| `/si` | Einstellungen öffnen |
| `/si lock` | Bearbeitungsmodus öffnen, um das Fenster zu verschieben und zu gestalten |
| `/si kick` | Eigene Unterbrechung manuell als benutzt markieren (Reserve, falls die automatische Erkennung eine verpasst) |
| `/si version` | Installierte Version anzeigen |

---

## ❓ FAQ

**Müssen alle Gruppenmitglieder das Addon haben?**
Alle, die es haben, teilen ihre Abklingzeiten. Spieler ohne Addon können nicht erfasst werden – je mehr es nutzen, desto besser die Rotation.

**Wo sind die Optionen hin?**
Fast alle Optionen sind in den Bearbeitungsmodus umgezogen, damit du jede Änderung sofort siehst. Die normale Einstellungsseite enthält noch die Prioritätszuweisung und die Profile.

**Etwas funktioniert nicht / ich habe eine Idee!**
Bitte eröffne ein Issue auf [GitHub](https://github.com/apnotix/SexyInterrupter/issues) – Fehlerberichte und Wünsche sind willkommen.

---

## 🙏 Credits

Entwickelt mit [Ace3](https://www.wowace.com/projects/ace3), LibSharedMedia-3.0, LibDBIcon, LibDataBroker und [EditModeExpanded](https://github.com/teelolws/EditModeExpanded) von teelolws.

**Mit ❤️ von apnotix – viel Spaß beim Kicken!**
