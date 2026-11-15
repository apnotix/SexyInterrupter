3.0.47

- Positions: when switching to the new Edit Mode dialog the old position of some players was not taken over and the window sat at its start position again. The Interrupt window could even be moved back about 2 seconds after loading. The takeover now retries later, falls back to the layout the window was moved in, no longer deletes the old data and no longer lets the computed start position win. Windows that were already reset need to be placed once more
- Speech (text to speech): optionally speaks "Interrupt!" (or the spell name, or both) when it is your turn, with voice, speed and volume and a test button. Only offered if the client knows text to speech
- Spell list per instance: every spell your target casts inside a dungeon or raid is remembered and listed (Edit Mode, "Spell list per instance"), one collapsible section per instance with a check box per spell. With the option "Respect the spell list in instances" unticked spells no longer trigger the card, sound, flash or speech there. You can add your own spells by name and clear a list. The "Interrupt now" card has a button to mute or re-enable the current spell. /si kicklist prints the list

3.0.46

- Edit Mode: Oben im Dialog verweisen Links auf zusammengehörige Fenster (Interrupts, Unterbrich jetzt, Gegner-Marker); ein Klick zeigt deren Einstellungen
- Solo (keine Rolle bekannt): Der Name beginnt links, ohne Platz für das fehlende Rollen-Symbol
- New Edit Mode dialog in the look of the other Sexy addons with collapsible sections (behavior, look, text, position and size, visibility) from the own SexyEditMode library; EditModeExpanded and LibUIDropDownMenu are gone. New: hide, hide in combat and show only on mouseover per window. Font, statusbar and sound lists are scrollable menus (without live font previews). Settings stay in the profile; the saved position is kept
- Interrupt window polish: flat bar texture ("Flat", new default), no text outline (soft shadow instead), icons scale with the bar height and sit 6 px from the right edge, default bar height 26
- Background and border color can no longer be changed (the "Background color" and "Border color" options are gone); saved choices are no longer used
- Edit Mode: the interrupt window keeps its top edge when the row count changes ("Grow direction: Downward" is applied once per profile, the option stays selectable), and the saved position now remembers the height it belongs to, so the window no longer ends up at the bottom of the preview frame
- Own-row highlight: only the golden tint stays, the 3 px golden strip on the left is gone
- Interrupt bars match the frame: gold-brown fill (ready) and dark brown (cooldown), a thin border in the window border color around every bar, and a border around the ability icon on the right
- "Interrupt now" card: pulsing red glow around the card (same glow as the winner card in SexyLoot)
- New look like SexyQuestHelper and SexyLoot for all windows: dark brown panel with the same gold tooltip-style frame as SexyQuestHelper, title band with a badge, card rows with dividers and colored status labels
- Interrupt window: band "Interrupts" with the number of ready kicks; each row shows a label (dead / offline) or the cooldown number, the bar turns amber while the cooldown runs
- "Interrupt now" is now a card with a red frame: icon and cast name of the target, remaining cast time, target name in large type. The display time now follows the cast length in seconds (it used milliseconds before)
- Enemy marks window: title band with the number of marked enemies shown
- New fonts: Marcellus for titles, Inter for text (bundled, SIL Open Font License, registered with LibSharedMedia; Inter is the new default font). Russian, Korean and Chinese clients keep the game font
- The "Background" and "Border" texture options are gone (flat panel); background, border, bar and font colors stay adjustable
- New default colors for new profiles and for settings that were never changed (gold border, dark brown background, bars colored by state, class-colored names)
- Enemy marks window is back, now styled like the interrupt window (same backdrop, border, bar height, texture, fonts and colors)
- Enemy marks: rows stay in fixed slots in combat so a click always targets the mob shown in that row; hidden window no longer leaves invisible clickable areas
- Interrupt window: no more size/anchor changes in combat (avoids blocked-action errors)
- "Show display glow/flash" option renamed; the flash now also ends on target change/cast stop when "Show message" is off, and stops immediately when the option is switched off
- Teammates are only listed as interrupters once their client reports a learned interrupt (fixes fresh characters like new druids showing up)
- New command /si probe: logs symbol/death/health readability of marked enemies in combat (diagnostics)

3.0.44

- Shaman Frost Shock and Flame Shock now count as Earth Shock usage (shared cooldown)
- Own interrupt cooldowns are now also detected actively (SPELL_UPDATE_COOLDOWN) and broadcast to the group

3.0.43

- Enemy marks window temporarily disabled while click/death detection was unreliable in combat

3.0.42

- Fixed a Lua error when opening Edit Mode caused by unnamed click buttons in the interrupt window

3.0.22 - 3.0.41

- New enemy marks window: unit frames of enemies carrying a raid symbol, with health bar, cast bar (interruptible casts highlighted), Edit Mode position and options (show/combat only/cast bars/symbols/sorting/max rows/width)
- Works with "secret values" in combat: raid symbol taken from the nameplate, dead mobs detected via UnitIsDead, duplicates merged via GUID/nameplate, group members' targets used as fallback
- Click a mob row to target it (/targetexact for nameplate units); click a player row in the interrupt window to target that player; hover shows the unit tooltip
- White border around the row of your current target in both windows
- New diagnostics: /si marks, /si marks reset

3.0.21

- Spell ranks of the same ability (e.g. Pummel 1/2, Earth Shock 1-10) are shown as one row per player

3.0.20

- Fixed a Lua error when dead/offline/AFK state came back as a secret value in combat

3.0.17 - 3.0.19

- "Show message", "Play sound", "Flash display" and "Show chat message" are now enabled by default (existing profiles are migrated once)

3.0.16

- Range check works in combat, revived players lose the red name, fixed duplicate entries, new /si range command

3.0.15

- Pet interrupts (e.g. Warlock Spell Lock) are credited to the owner

3.0.14

- More Classic interrupt ranks (Shield Bash, Kick, Pummel, Spell Lock)

3.0.13

- Fixed an expired cooldown staying at 0.0

3.0.12

- Highlight own row, fixed rotation order mode, offline rows stay visible, Earth Shock ranks, /si debug

3.0.11

- New Edit Mode checkbox "Ignore healers" for the interrupt rotation

3.0.10

- Solo: only your own entry counts, new checkbox "Active when solo"
- Minimap icon uses the addon icon

3.0.9

- Addon icon registered in the TOC

3.0.8

- Fixed a client crash (access violation) when closing Edit Mode: the preview message is no longer shown inside the message frame

3.0.1

- Fixed a client crash ("Access denied") when dragging the Edit Mode window
- Fixed the window resetting to its default position after /reload
- Fixed group member bars briefly disappearing on zone change
- Fixed role changes not syncing immediately to the group

2.4

- Config fixes
- Range kick cooldown sync fix
