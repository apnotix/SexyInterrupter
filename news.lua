-- Neuigkeiten für das gemeinsame Fenster (SexyEditMode, /sem news). Neueste Version zuerst.
-- Eintrag: { deutscher Titel, deutscher Text, englischer Titel, englischer Text }
local SEM = LibStub and LibStub("SexyEditMode-1.0", true)
if not (SEM and SEM.RegisterNews) then return end

SEM:RegisterNews("SexyInterrupter", {
	color = { 0.78, 0.48, 1 },
	{ v = "3.0.49",
		{ "Zauber anderer Gegner", "Neue Option „Auch Zauber anderer Gegner in der Nähe melden“ (an): Der Hinweis kommt jetzt auch für Gegner, die nicht dein Ziel sind (über ihre Namensschilder, wie LittleWigs bei Trash). Nur Feinde im Kampf, höchstens alle zwei Sekunden.",
		  "Casts of other enemies", "New option \"Also report casts of other nearby enemies\" (on): the hint now also comes for enemies that are not your target (through their nameplates, like LittleWigs does for trash). Only enemies in combat, at most every two seconds." },
		{ "Befehl /si add", "Mit „/si add Zaubername“ (auch als Makro) kommt ein Zauber auf die Liste der Instanz. Ohne Namen nimmt er den Zauber, den dein Ziel gerade wirkt; im Kampf ist der Name oft geheim, dann den Namen angeben.",
		  "Command /si add", "\"/si add spell name\" (also usable in a macro) adds a spell to the list of the instance. Without a name it takes the spell your target is casting right now; in combat the name is often secret, then give the name." },
		{ "Zauberliste", "Die Seite „Zauberliste pro Instanz“ hat links die Instanzen (deine aktuelle zuerst) und rechts die Zauber der gewählten: abhaken, entfernen, mit dem Feld suchen oder einen neuen Zauber hinzufügen.",
		  "Spell list", "The page \"Spell list per instance\" has the instances on the left (your current one first) and the spells of the chosen one on the right: tick, remove, search with the field or add a new spell." },
		{ "Nur Heilzauber", "Neue Option „Ton und Sprache auch, wenn die Zauberart unbekannt ist“ (an): Im Kampf ist die Zauber-ID oft geheim, dann bleiben Ton und Sprache bei „Nur Heilzauber melden“ stumm. Mit der Option kommen sie bei jedem Zauber, Karte und Blitz bleiben auf Heilzauber gefiltert.",
		  "Healing spells only", "New option \"Sound and speech even if the spell kind is unknown\" (on): in combat the spell ID is often secret, so sound and speech stay off with \"Only report healing spells\". With the option they play for every cast, while the card and the flash stay filtered to heals." },
		{ "Interrupt now", "Nicht unterbrechbare Zauber werden nicht mehr gemeldet. Ist der Zauber geheim, bleiben Ton und Sprache aus.",
		  "Interrupt now", "Spells that cannot be interrupted are no longer reported. If the spell is secret, sound and speech stay off." },
		{ "Markierungen", "Neues Aussehen: jeder Gegner ist eine Karte mit Farbstreifen in der Farbe seines Symbols, Name, Prozent und Gesundheit, darunter eine höhere Zauberleiste nur während eines Zaubers, mit Zaubername links und Restzeit ganz hinten (unterbrechbare in Gold mit goldenem Rand). Karten ohne Zauber sind niedriger, die darunter rücken nach. Ein Klick auf eine Karte visiert den Gegner an (die Klickflächen waren bisher nie angelegt). Eigene Vorschau mit vielen Einstellungen.",
		  "Enemy marks", "New look: every enemy is a card with a stripe in the color of its marker, name, percent and health, below it a cast bar only while the enemy casts, with the spell name on the left and the time at the far right (interruptible ones in gold with a gold border). Cards without a cast are shorter and the ones below move up. A click on a card targets the enemy (the click areas had never been laid out). Own preview with many settings." },
		{ "Vorschau", "Liste und „Interrupt now“ haben je eine eigene Vorschau mit erfundenen Spielern, laufenden Balken und neuen Einstellungen.",
		  "Preview", "The list and \"Interrupt now\" each have their own preview with invented players, running bars and new settings." },
		{ "Profile", "Die Einstellungen liegen jetzt im gemeinsamen Profil aller Sexy-Addons; alte Profile werden übernommen.",
		  "Profiles", "Settings now live in the shared profile of all Sexy addons; old profiles are migrated." },
	},
})
