3.0.49

- Spell list per instance: the lists are saved for the whole account now (all characters and all profiles share them), not inside the profile any more. Lists that still sit in a profile (older version, or a profile you switch to or import) are merged into the account lists automatically: new spells are added, settings already in the account stay.
- Spell list per instance: new page layout with the instances on the left (the one you are in first, marked green, with the number of spells) and the spells of the chosen instance on the right: tick a spell to report or mute it, "x" removes it, the field above filters while you type and adds the text as a new spell with Enter or "Add spell"; the footer shows the count and "active here". Needs the new SexyEditMode (without it the old list stays).
- Enemy marks: the cards are different heights now: a card without a cast ends under the health bar and the cards below move up, a card with a cast grows by the cast bar. In combat the layout stays as it was (the click areas cannot move there); a cast that starts on a small card replaces the health bar for its duration. Name and percent use a font two points smaller than the list.
- Fix enemy marks: the click areas over the cards were never laid out (the function was never called), so a click on a card did not target the enemy. They sit over the cards now and follow their heights.
- Enemy marks: new card look. Every enemy is a card (default 40 px, 6 px apart) with a stripe in the color of its marker, marker, name and health percent on top and a health bar below. While the enemy casts, a cast bar (default 14 px) appears at the bottom with the spell name on the left and the remaining time at the far right inside the bar; without a cast there is no cast bar and the card ends under the health bar (the cards below move up; in combat the layout stays as it was so the click areas keep their place, and a cast that starts there replaces the health bar for its duration). An interruptible cast turns the bar and the card border gold. The default health color is brighter, the default highlight strength 12 %.
- Enemy marks: the cast bar sits below the health bar now (the row gets taller by its height) instead of on top of it, so a tall cast bar no longer covers the name.
- Settings window: the enemy marks window has its own preview window now (health drops, casts loop; width, rows, header, cast bars, highlight, sorting and the symbol selection apply at once). The settings sit in the first group (look, with the symbols); behavior is the second.
- Enemy marks: new look settings (row height, row spacing, window opacity, active counter, marker icon, health percent, frame around the target, health color, cast bar height, cast name, interruptible / not interruptible colors, highlight color and strength), all shown in the preview.
- New look settings, all shown in the preview: list (row spacing, window opacity, ready counter, square bars, separate role icon and spell icon, cooldown number, text outline) and "Interrupt now" card (width, icon size, name size, badge, spell label, time label, cast bar, pulsing glow with color). "Interrupt now" has its own preview window now. The look settings sit in the first group; behavior settings in the second.
- Settings window: the list preview is its own window with its own logic (samples.lua): the example players are sorted like the real list, the bars and times count down smoothly, and the settings (width, bar height, rows, colors, class icon, ignore healers, fixed rotation, header) apply at once. New file: needs a full client restart.
- The preview rows now make sense: ten invented players with their class, role, kick and cooldown, sorted like the real list (ready first, then by remaining time, ties: tank before damage before healer). The bars count down and the preview starts over after 40 seconds.
- The preview rows (Edit Mode and settings window) use invented names (Brom, Selene, Kael, ...) and the target "Gloomtooth Mage" instead of "Preview ...".
- Settings window: the list, "Interrupt now" and the enemy marks show the real window with the Edit Mode sample data in the preview on the right (hover a part, click to jump to its setting).
- "Hide header" for the "Interrupt now" card and the enemy marks window as well (the list had it already).
- The list window is now called "Interrupter" (was "Interrupts" / "Unterbrechungen").
- New checkbox "Hide header" for the list window: the title band disappears and the rows move up.
- "Only report healing spells" also works with secret spell IDs where the client allows it: the card and the flash are shown or hidden through the secret value (sound and speech cannot follow, so they stay off in that case).
- New setting "Only report healing spells": the hint only comes for heals. The addon reads the spell description (heal words, German and English) and, if that is not available, asks whether the spell targets friends. If the spell cannot be read (secret values in combat) it is reported as before. `/si debug` prints the result and the method used.
- Less nagging when playing solo: new setting "Pause between hints when solo" (default 8 s) so a mob that casts quickly one after another does not trigger "Interrupt now" every time, and "Ignore casts shorter than" for casts too short to kick.
- The list rows have a small gap (3 px) between them. Class colors are slightly muted (the rogue yellow was very bright).
- Kicks of players without the addon are now also detected from the "spell interrupted" event, if the client says who interrupted (`/si debug` prints every event with the name or `nil`/`SECRET`). The ability is the one already seen for that player, otherwise the typical kick of the class.
- A player whose kick has not been seen yet now shows the typical interrupt of his class (e.g. Pummel for warriors) as a dimmed icon; as soon as he really kicks, the real spell and cooldown replace it.
- Interrupters out of range: the row is dimmed less (60 % instead of 40 %) and the name no longer gets an extra fade, so you can still read who it is.
- List text is white with a black outline (class colors for the names are off by default; existing profiles are switched once, you can turn them back on in the settings). The rounded corners stay clean on mouse-over.
- Bars have a glassy gloss like the XP bar, the list rows have rounded corners. The Edit Mode preview rows now show an ability icon with frame in every row, like the real list.
- SexyEditMode is now a required dependency (CurseForge installs it automatically).
- Docking: every window can be docked to another window (also of other Sexy addons), with side and alignment (needs the SexyEditMode addon).
- Minimap button / /si lock: Edit Mode only for the windows of SexyInterrupter (needs the SexyEditMode addon).
- Edit Mode: the three windows (list, Interrupt now, enemy marks) have tabs at the top of their dialog (needs the SexyEditMode addon).
- The "Interrupts" window no longer stays visible when it has no rows (it used to count every known player, even those filtered out, e.g. by "Ignore healers" or "Active when solo").
- With the SexyEditMode addon the Edit Mode dialogs of the windows show only visual options (look, size, position, visibility); behavior options (when it shows, sounds, speech, minimap icon, symbols, ...) are in the shared settings window. Without the addon everything stays in the dialogs.
- Minimap button: with the SexyEditMode addon, left click opens the settings window at SexyInterrupter, right click toggles Edit Mode (without it, as before). The options with assignments and profiles still open with /si.
- "Interrupt now" sound: the game sounds of "Quests nearby" (quest list, ready check, raid warning, ...) are offered at the top of the sound list, before the LibSharedMedia sounds.
- The sound list no longer offers "None"; the "Play sound" checkbox switches the sound off.
- New text field "Spoken phrase" (Edit Mode / shared settings, Speech): type the sentence that is spoken when it is your turn. Empty or the default text means "Interrupt!". It is used for "Phrase" and "Phrase and spell name"; "Test speech" speaks it too.
- "Test speech" works again: the text-to-speech call used an old parameter order, so speed and volume were shifted. A failing call now shows its error in the chat.
- The spell list per instance is its own page in the shared settings window (SexyEditMode, /sem) instead of a section in the "Interrupt now" dialog.
- Voice selection: the voice names are shortened ("Hedda - German" instead of "Microsoft Hedda Desktop - German"), and long entries no longer run out of the list.
- Registers with the new SexyEditMode addon: if it is installed, the windows (list, Interrupt now card, enemy marks) also appear in its shared settings window (/sem). Nothing changes without it.
- Font selection: every font in the list is shown in its own typeface, and so is the current choice.

3.0.48

- The screen flash has an adjustable color (Edit Mode, "Interrupt now" dialog) and a test button; the default stays blue
- "Interrupt now" card: spell name, icon and cast progress show up again. In combat the client hands these over as protected values; they were thrown away and the card stayed empty. They are now passed straight to the display (text, icon, progress bar) and only calculated inside protected calls, so a protected value no longer breaks the card

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
