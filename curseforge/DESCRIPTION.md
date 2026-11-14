# SexyInterrupter

![WoW Forever](https://img.shields.io/badge/WoW-Forever-e8c26a?style=for-the-badge) ![WoW Retail](https://img.shields.io/badge/WoW-Retail-c8a24a?style=for-the-badge) ![Interface](https://img.shields.io/badge/Interface-120100%20%7C%2016001-3b2b12?style=for-the-badge)

**Stop the cast. Share the kick. Never argue about "who's next?" again.**

SexyInterrupter tracks who in your party or raid can interrupt, shows every player's interrupt cooldown live and tells you the moment it is your turn to kick. No setup, no chat spam.

Works on **World of Warcraft: Forever** and **Retail**. Styled like the other Sexy addons: dark brown panel, gold frame, title band with a badge.

## Features

- 🎯 **Smart kick order** - the whole group sorted by who is ready first, then by role priority. The next player is always on top, with labels for dead and offline players and the number of ready kicks in the title.
- 📣 **"Interrupt now!" card** - when your target casts and it is your turn: target name, spell icon, spell name and remaining cast time on a red glowing card. Optional sound and screen flash.
- 🧠 **Learns interrupts by itself** - every player's interrupt is detected as it is used. Several interrupts per player each get their own row, icon and cooldown.
- 🔄 **Live group sync** - cooldowns, roles and spec changes are shared between everyone running the addon. Out-of-range players are dimmed.
- 💀 **Enemy marks window** - lists attackable targets with a raid symbol, with health and cast bar; interruptible casts are highlighted and a click targets the mob.
- 🥇 **Priority overrides** - group leaders can change who kicks first.

## Edit Mode

Almost everything lives in **Blizzard's Edit Mode**: click a window and adjust it with a live preview. The dialog has collapsible sections and links between the three windows (kick order, interrupt card, enemy marks).

- Layout: width, bar height, rows, grow direction
- Look: fonts (Marcellus, Inter or any SharedMedia font), status bar texture, bar and font colors, class colors
- Notifications: message, sound with preview, screen flash, chat announcement (Say, Yell, Party, Raid)
- Visibility: show in combat only, hide, mouseover, minimap button

## Commands

| Command | Description |
|---|---|
| `/si` | Open the settings |
| `/si lock` | Open Edit Mode |
| `/si kick` | Mark your interrupt as used by hand (backup if auto-detection misses one) |
| `/si version` | Show the version |

Long form: `/sexyinterrupter`

## Notes

- Everyone who runs the addon shares cooldowns. The more players have it, the better the rotation.
- Settings are saved per profile. Positions and options of earlier versions are carried over.
- Fonts: Marcellus and Inter are bundled (SIL Open Font License).
- Bug reports and ideas are welcome on GitHub.

## Credits

Built with Ace3, LibSharedMedia-3.0, LibDBIcon, LibDataBroker and the own SexyEditMode library. Fonts: Marcellus and Inter (SIL Open Font License 1.1).

## 🇩🇪 Deutsch

**SexyInterrupter** zeigt, wer in deiner Gruppe unterbrechen kann, wie lange jede Unterbrechung noch braucht, und meldet dir, wann du dran bist.

- Kick-Reihenfolge der ganzen Gruppe mit Abklingzeiten, Karte „Unterbrich jetzt!“ mit Ton und Blitz
- Erkennt Unterbrechungen selbstständig, Gruppen-Abgleich in Echtzeit
- Gegner-Marker-Fenster für Ziele mit Zeichen, Prioritäten für Gruppenleiter
- Alles im Edit Mode einstellbar, funktioniert auf Deutsch und Englisch

Ausführliche deutsche Beschreibung: https://github.com/apnotix/SexyInterrupter
