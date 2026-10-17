# Munda HP Display: what the fighter card supports

This page covers the Mundane Importer UI card for Fighters in Tabletop Simulator: every action, skill, piece of wargear, weapon trait, accessory and Wyrd power, and how the card handles each one. Rosters come from **MundaManager (N26 export)**.

**Disclamer:**
Only Core Rule functionality, Gangs of the Underhive and Gangs of the Outlands are currently supported.
Anything within the journals aside the gang rule is NOT supported, unless it is also directly in MundaManager.
This means stims and other special wargear from the journals must be resolved by hand for now or they may be supported by an existing core system. I will decide later when these get covered.
Note that Dramatis Persona / Hanger-Ons are currently also NOT supported and will not receive support until I get to them later.

## Legend

| Mark | Meaning |
| --- | --- |
| ✅ **Card** | The card plays it for you: it rolls the dice, changes the stats, asks the questions. |
| 📋 **Roster** | MundaManager already puts it in the fighter's statline or the weapon's profile, so the card shows it as imported. |
| 🎲 **Table** | Done by moving models on the table. The card has nothing to do. |
| ⚠️ **Partly** | The card does the main part; the note says what is left to you. |
| ❌ **Not yet** | The card doesn't do it yet. Play it by hand. |
| 🗓️ **Campaign** | Matters between battles, not on the card. |

Always in play:
- **Skills** stop working while the fighter is at 0 wounds, Seriously Injured or Out of Action.
- **Wargear** always works, even at 0 wounds.
- **Wyrd powers** still work at 0 wounds.
- A changed stat shows **green** when it is better, **orange** when worse and **purple** when a Wyrd power changes it. Hover the stat to see what changed it.
- Questions the card asks ("Did the target move?", "Fight Back?" and so on) open in the panel over the stats. The item/effect asking is named in the bar under the stats.

---

## Abilities

Abilities that are on specific gang fighter datasheets are currently NOT supported. This is mostly pets or special gangers like Hanger-Ons / Dramatis Personae.

---

## Actions

Actions are in the actions panel (hover "A"), sorted by status. Using an action spends its cost (S, D or F) and dims it until the activation ends.

| Action | Cost | Status | What the card does |
| --- | --- | --- | --- |
| Move | S | ✅ Card | Shows and says the distance in inches (M). |
| Dash | D | ✅ Card | Shows M + I in inches. After a Dash, ranged weapons can't fire, except Assault ones. |
| Engage | S | ✅ Card | Rolls the D6 and shows the inches. The next Fight or Coup de Grace is free. |
| Charge | D | ✅ Card | Rolls M + D6 and shows the inches. I +2 until the activation ends, the next Fight is free, and charge bonuses apply (Bull Charge, Lance, Jump Booster). |
| Coup de Grace | S | ✅ Card | Rolls off against the selected enemy, on both cards: D6 + S each. Equal or higher takes it Out of Action. |
| Interact | S | ✅ Card | Spends the action and says so. What it does is up to the table. |
| Shoot | S | ✅ Card | Pays for the next shot from a weapon popup. One per activation, unless a skill allows more. |
| Braced Shot | D | ✅ Card | For Heavy weapons. Pays for the shot. |
| Aimed Shot | D | ✅ Card | Every weapon that can aim opens aimed: +1 to hit (more with Sharpshooter or a Mono-Sight). |
| Reload | S | ✅ Card | Reloads the one profile that is out of ammo (Scarce rolls first). With several out, click the OUT of the one to reload. |
| Treat Ally | S | ✅ Card | Opens the Recovery Test of the selected Seriously Injured friend within 1". |
| Group Activation | S | ✅ Card | A Leadership check, -1 for each Ready friend selected after the first. Passed: friends within 3" are marked ⚡ and activate after. |
| Fight | D | ✅ Card | Pays for the round of close combat: the first weapon is the primary ("A + 1"), a second one opens at x1. |
| Retreat | D | ✅ Card | Shows the distance (I). |
| Crawl | D | ✅ Card | Shows the distance (S). |
| Desperate Escape | D | ✅ Card | Rolls the die. The fighter goes Out Cold or Out of Action as it says. |
| Tend Wounds | D | ✅ Card | Adds its die to the fighter's own Recovery Test. |
| Recovery Test | – | ✅ Card | Opens the Recovery Test panel (dice from helpers, a Medicae Kit, Tend Wounds). |
| Maintain Control | S or F | ✅ Card | Keeps a Continuous Wyrd power in effect. |
| Concentrate | S | ✅ Card | Wyrd: a bonus to its Willpower checks to manifest powers until the activation ends. |

**Special tab** (any status): Roll Dice, Roll Firepower, Roll Injuries, Agility Test, Falling Down, Nerve Check, Recovery Test and Out of Action. Each rolls and shows its result. Falling Down works out the fall's height, test, wounds and Injury dice.

**Activation flow** (✅ Card): Ready / Active marks, the actions left, the Nerve Check, Recovery Test and Out of Action panels, Fight Back when taken Out of Action in a fight, and automatic Engaged when models are placed in base contact.

---

## Skills

| Skill | Status | What the card does |
| --- | --- | --- |
| **Agility** | | |
| Catfall | ✅ Card | A fall counts one level less. An Active fighter then makes an Agility test: passed, it isn't Suppressed. |
| Clamber | 🎲 Table | Climbing is moved on the table. |
| Dodge | ✅ Card | After the saves, a D6 for each wound that goes through: a 6 dodges it. Not against Blast, Template or Web. |
| Mighty Leap | 🎲 Table | Leaping is moved on the table. |
| Spring Up | ✅ Card | Activating while Suppressed: an Agility test, passed gives the second action back. |
| Sprint | ✅ Card | Sprint (D) on the Special tab while Active: M + 2× I, shown in inches. |
| **Brawn** | | |
| Bull Charge | ✅ Card | On the charge: melee weapons +1 S and Knockback (6+), shown in green. |
| Bulging Biceps | ⚠️ Partly | A Heavy melee primary still allows a second, non-Heavy weapon. **Not yet:** the Braced Shot move (up to I" before or after). |
| **Combat** | | |
| Berserker | ✅ Card | The Frenzy condition (+1 A) while the skill works. |
| Combat Master | ✅ Card | Always gives Assist and always Interferes. Never suffers Interference. |
| Counter-Attack | ✅ Card | Attacking in melee outside its own activation (fighting back): the weapon opens at x2 instead of x1. |
| Headbutt | ✅ Card | Adds a Headbutt weapon (E, S+1, AP -, L1, Additional Attack (1), Melee). |
| Heavy Blows | ✅ Card | +1 S on melee weapons with Heavy. |
| Rain Of Blows | ✅ Card | Still Engaged after the first round of close combat: a second round, free. |
| Two-Weapon Fighter | ✅ Card | The second weapon of a round opens at x2. |
| **Ferocity** | | |
| Fearsome | ✅ Card | The Fearsome condition while the skill works: an enemy attacking it in melee during its own activation makes a Willpower check first, failed: Feared (WS 6+). |
| Iron Jaw | ✅ Card | T +2 against melee hits with AP "-" (Light weapons in a fight too). Not against Toxin. |
| Nerves Of Steel | ✅ Card | A ranged hit that would Suppress it: a Cool check first, passed: not Suppressed. |
| Unstoppable | ✅ Card | Activating while wounded: a Willpower check, passed: 1 wound back. |
| **Cunning** | | |
| Backstab | ✅ Card | Every melee weapon counts as Backstab. One with the trait gets +2 S. |
| Cut-Throat | ✅ Card | Coup de Grace: when the enemy rolls higher, its die is rolled again once. |
| Infiltrate | 🎲 Table | Set up on the table before round 1. |
| Lie Low | ✅ Card | While Suppressed, a ranged attack from beyond the weapon's Short Range asks the shooter first (Continue or call off). |
| Overwatch | ❌ Not yet | Interrupting an enemy's action to shoot it. |
| **Leadership** | | |
| Inspiring | ✅ Card | Group Activation costs a Free action. |
| Iron Will | ✅ Card | The gang's Bottle Check on the Mundane Controller gets +1. |
| Juggernaut | ✅ Card | Hit by a ranged attack: Suppressed only once the attack is over, and only if a wound went through. |
| **Savant** | | |
| Connected | 🗓️ Campaign | |
| Fast Reload | ✅ Card | A Reload reloads every weapon that is out of ammo. |
| Medicate | ✅ Card | Heal Ally (S) on the Special tab, Active or Suppressed: the selected friend (or the medic itself) regains 1 wound. |
| Mentor | 🗓️ Campaign | |
| Munitioneer | ✅ Card | Distribute Ammo (S): friends within 6" with a weapon out of ammo make an Int check, passed: reloaded. |
| **Shooting** | | |
| Fast Shot | ✅ Card | Two Shoot actions per activation. |
| Gunfighter | ✅ Card | A Shoot with a Light weapon lets a second Light weapon fire too, for no action. |
| Hip-Shooting | ✅ Card | Ranged weapons without Heavy count as Assault. |
| Marksman | ✅ Card | +1 to hit beyond Short Range (within Long), shown on the weapon. |
| Precision Shot | ✅ Card | A natural 6 to hit (not Blast or Rapid Fire): no armour save against that wound. |
| Sharpshooter | ✅ Card | Aimed Shot +2 to hit instead of +1. |
| **Other** | | |
| Hit & Run | 🎲 Table | The consolidation is moved on the table. |

---

## Wargear

| Wargear | Status | What the card does |
| --- | --- | --- |
| Bio-Booster | ✅ Card | The first wound that takes the fighter to 0 has 1 less Lethality. At Lethality 0: 2 Injury dice, the better kept. Then it is used up (grey). |
| Bomb Delivery Rats | ❌ Not yet | Listed under the stats only. |
| Carapace Armour (Light / Heavy) | 📋 Roster + ✅ Card | Sv and I are in the statline. Heavy: -1 to every Agility test, shown as "Agility Test (-1)". |
| Chaos Familiar | ❌ Not yet | Listed under the stats only. |
| Cult Icon | ✅ Card | A failed Group Activation check is re-rolled once. |
| Dirt Bike | 📋 Roster | The mount's stats come from the roster. Its M can't be changed by wargear or Wyrd powers. |
| Drop Rig | ✅ Card | Descend (S): 3" horizontally, 12" vertically, shown. |
| Grapnel Launcher | ✅ Card | Grapnel (D): 12" straight, ending higher, shown. |
| Grav Chute | ✅ Card | A fall does nothing: no test, no damage, not Suppressed. |
| Hazard Suit | ✅ Card | Immune to Blaze and Rad-Phage. |
| Medicae Kit | ✅ Card | Assisting a Recovery Test adds an Injury dice, the best kept. |
| Mesh Armour | ✅ Card | Sv one better against close combat attacks (melee, and Light weapons used in a fight). |
| Photo-Goggles | ✅ Card | -2 to the Initiative check against Flash. Seeing through smoke is the table's. |
| Photo-Lumens | 🎲 Table | Visibility is the table's. |
| Reflec Shroud | ✅ Card | Las, Plasma and Melta weapons count as AP "-" against it. |
| Refractor Field | ✅ Card | 5+ invulnerable save. Burnt out on a natural 1 (grey, click to switch it back). |
| Respirator | ✅ Card | 5+ invulnerable save against Gas. |
| Servo-Harness (Partial / Full) | 📋 Roster | Its stat changes must come from MundaManager's statline. |
| Stimm-Slug Stash | ✅ Card | Stimm-Slug (F, once a game): M, S and T +2 until the next activation, then a D6: on a 1, a wound with no save. |
| Extra Arm (rule or wargear) | ✅ Card | Braced Shot costs S, never in the same activation as a Move or a Shoot. |

### Gang wargear and mutations

Outcast mutations come in the roster as wargear.

| Wargear | Gang | Status | What the card does |
| --- | --- | --- | --- |
| Seven-Pointed Breastplate | Outcasts | 📋 Roster | Sv +1 must come from MundaManager's statline. Whether it does is not confirmed yet. |
| Conduit Of Ozostium | Outcasts | ✅ Card (import) | The importer adds the Wyrd subtype and the Force Blast power, if the roster doesn't already have them. |
| Gloves Of Ozostium | Outcasts | ✅ Card (import) | The importer adds the Wyrd subtype and the Flaming Weapon power, if missing. |
| Seven-Pointed Talisman | Outcasts | ✅ Card | Cl +1 for the bearer and for every fighter (friend or foe) within 6" while they are there. |
| Void Soul | Outcasts | ✅ Card | A Wyrd power cast with it selected as a target asks first: Continue casts, X calls the power off (nothing spent). |
| Extra Appendage | Outcasts | 📋 Roster | +1 A in the statline. A fourth weapon goes to the W4+ list. |
| Horrific Appearance | Outcasts | ✅ Card | Fearsome, always (at 0 wounds too). |
| Massive Claws | Outcasts | 📋 Roster | The roster's own weapon. |
| Needle Spines | Outcasts | ✅ Card | Sv one better in close combat. Fire Spines (S, once a battle): everyone else within 3" takes an automatic Toxin (3+) hit (S -, AP -, L1), resolved nearest first. Afterwards the item is greyed out and the Sv bonus is gone. |
| Tentacles | Outcasts | ✅ Card | A failed Agility test is re-rolled once ("Agility Test (RR)"). |
| Toxic Blood | Outcasts | ✅ Card | Each wound that goes through its saves (until it is at 0 wounds) counts. Once the attack is over, everyone else within 1" makes that many Agility tests, and each failure is an automatic Toxin (3+) hit, resolved nearest first. |
| Wing Membranes | Outcasts | ✅ Card | Falling Down asks "Jumping down?": yes, the Agility test passes whatever the die. |
| Exo Suit | Ironhead Squats | ✅ Card | Immune to Blaze and Rad-Phage. |
| Book Of The Redemption | Cawdor | ❌ Not yet | Words of Wrath. |
| Pyromantic Mantle | Cawdor | ✅ Card | During its activation, melee weapons gain Blaze (5+). A Blaze of its own stays as it is. |
| Psychomancer's Harness | Delaque | 🎲 Table | Movement only. |
| Jump Booster | Orlock | ✅ Card | On activating it asks "Activate Jump Booster?". Yes: for that activation M +3 and Flying; on the charge +1 to hit with every weapon and +1 S; grenades and Template weapons become Unstable. |
| Augurspex | Van Saar | 🎲 Table | Set-up distance only. |
| Refraction Cloak | Van Saar | ✅ Card | A shot at it asks "Did the target move?": yes -1 to hit, no -2. |
| Servo-Medicae | Van Saar | ✅ Card | Auto-Medicate (F): an Int check, passed: the selected fighter (itself or a friend) regains 1 wound. |
| Vox Array | Van Saar | ✅ Card | Group Activation is a Free action, at 0 wounds too. |
| Magnacles | Palanite Enforcers | ✅ Card | Restrain (D, while Engaged): the selected enemy makes an Agility test, failed: Webbed. |
| Corpse Grinder Cult Icon | Corpse Grinder Cults | ✅ Card | Enrage (S): Ready, Active friends wholly within 6" each roll a D3 and add it to M until the end of the round. |

**Flying** (subtype, or a Jump Booster in use): Falling Down asks "Flying, continue?". Yes: no test, no harm. X: no fall.

---

## Weapon traits

| Trait | Status | What the card does |
| --- | --- | --- |
| Additional Attacks (X) | ✅ Card | X more attacks, once a round, never the primary or second weapon. |
| Ammo (X+) | ✅ Card | The Ammo die after firing: below X, out of ammo. |
| Arc (X) | 🎲 Table | Field of fire. |
| Assault | ✅ Card | After a Dash, one Shoot with it for no action. |
| Auxiliary | 📋 Roster | |
| Backstab | ✅ Card | +1 S when a friend is fighting the target too. |
| Blast (3" / 5") | ⚠️ Partly | Hit roll, scatter on a miss, misfire on a double 1, then you select the fighters under the marker and each is resolved on its own card. **Not yet:** with Rapid Fire, the extra markers aren't rolled. |
| Blaze (X+) | ✅ Card | A Wound roll of X+ makes one more hit. |
| Breaching (X+) | ✅ Card | A Wound roll of X+: no armour save for that wound. |
| Combi | ✅ Card | One profile, or both at the same target at -1 each. |
| Concussive (X+) | ✅ Card | A Wound roll of X+: Concussion (I -1) until the end of the next activation. |
| Cursed | ✅ Card | A fighter hit makes a Willpower check, failed: Insanity. A natural 1 to hit curses the wielder. |
| Damage (X) | ✅ Card | Each wound takes X wounds. |
| Drag | ⚠️ Partly | A D6 against the target's S drags it 1-3". **Not yet:** for Blast or Template hits. |
| Flash | ✅ Card | No Wound roll: an Initiative check, failed: Blind, and the target loses its Ready marker. |
| Gas | ✅ Card | No armour save (a Respirator gives 5+ invulnerable). |
| Graviton Pulse | ✅ Card | No Wound roll: a Strength check, failed: wounded, no armour save. The marker's terrain effect is the table's. |
| Heavy | ✅ Card | Braced Shot only, no Aimed Shot. In melee: no second weapon (unless Bulging Biceps). |
| Independent | ❌ Not yet | Firing alongside the bearer at its own target. |
| Knockback (X+) | ✅ Card | A Hit roll of X+ pushes the target 1". Blast: a D6 per fighter caught. |
| Lance | ✅ Card | +1 S on the charge for a Mounted fighter. |
| Lance-Bomb | ✅ Card | Its first hit spends it (SPENT, click to prime again). |
| Light | ✅ Card | Usable while Engaged, as part of the Fight. |
| Limited | ✅ Card | Out of ammo for good (SPENT). |
| Melee | ✅ Card | Used while Engaged. |
| Paired (X) | ✅ Card | A + X as the primary. No second weapon beside it. |
| Parry | ✅ Card | Sv +1 against close combat attacks. |
| Power Pack | 📋 Roster | |
| Rad-Phage | ✅ Card | A wound: Radphage (T -1). |
| Ram | ❌ Not yet | Only usable after a Charge. |
| Rapid Fire (X) | ✅ Card | RF mode with Firepower dice. |
| Reckless | ❌ Not yet | Random target among the models near the intended one. |
| Reliable | ✅ Card | Ignores the first ammo symbol each round. |
| Rending (X+) | ✅ Card | A natural Wound roll of X+: AP one worse. |
| Scarce (X+) | ✅ Card | A Reload needs a D6 of X+. |
| Shield | ✅ Card | Sv +1 against ranged attacks from outside the fight. |
| Shock (X+) | ✅ Card | A Hit roll of X+ wounds automatically. |
| Shred (X+) | ✅ Card | A Wound roll of X+: Lethality +1. |
| Single Shot | ✅ Card | Fired once: SPENT. |
| Smoke | ✅ Card | Never wounds or Suppresses. The smoke cloud is the table's. |
| Template | ✅ Card | No hit roll. Every fighter selected is hit, each on its own card. |
| Toxin (X+) | ✅ Card | Wounds on X+ instead of S against T. |
| Twin-Linked | ✅ Card | A hit at Rapid Fire asks whether to re-roll the Firepower dice. |
| Unstable | ✅ Card | A natural 1 to hit turns on the shooter. |
| Unwieldy | ✅ Card | In close combat, I counts as 1. |
| Web | ✅ Card | No armour save. Webbed instead of losing a wound. |

**Every ranged hit Suppresses an Active target** (not Smoke). A shot at a Seriously Injured target is -1 to hit. Cover is asked at the save.

## Weapon accessories

| Accessory | Status | What the card does |
| --- | --- | --- |
| Focusing Crystal, Hotshot Las Pack, Infra-Sight, Suspensors | 📋 Roster | In the weapon's profile. The name is shown after the traits. |
| Las-Projector | ✅ Card | Within Short Range, 1 less cover. |
| Mono-Sight | ✅ Card | Aimed Shot +2 to hit. |
| Telescopic Sight | ✅ Card | Beyond Short Range, 1 less cover. |

---

## Wyrd powers

**Casting** (✅ Card): a power from the Special tab makes the Willpower test. Every enemy Wyrd within 18" is asked "Disrupt Power?" on its own card; the first to say yes rolls to disrupt (-2 to the caster, or a natural 2 stops the power), and the caster's card shows "Awaiting Disruption" with a Skip button meanwhile. A Continuous power stays in effect (⏳ before its name, the Maintaining Power condition) until it ends or isn't maintained. Click a Continuous power's name to switch it on or off by hand. Wyrd powers work at 0 wounds.

| Power | Cost | Status | What the card does once manifested |
| --- | --- | --- | --- |
| Force Blast | F/C | ✅ Card | Armed with the Force Blast weapon while in effect. |
| Flaming Weapon | F/C | ✅ Card | One melee weapon gains Blaze (5+) (click it if there are several). |
| Freeze Time | D | ✅ Card | Everyone within 12" gets one action when activated this round. |
| Weapon Jinx | S | ⚠️ Partly | Cast only. Play its effect by hand. |
| Terrify | D | ✅ Card | The selected enemy within 18" is Suppressed. If Ready, a Cool check, failed: it loses its Ready marker. |
| Quickening | S/C | ✅ Card | M +3, I +2 while in effect (may go past the highest). |
| Hypnosis | S | ⚠️ Partly | Cast only. |
| Unbreakable Will | F/C | ✅ Card | Friends within 9" may use the Wyrd's Wil and Cl. |
| Zealot | S/C | ⚠️ Partly | Cast only. |
| Mind Control | S | ⚠️ Partly | Cast only. |
| Assail | S | ✅ Card | A BS check, passed: the selected enemy is Suppressed. |
| Force Wave | S | ⚠️ Partly | Cast only. |
| Catalyst | F/C | ⚠️ Partly | Cast only. |
| Hypnotic Gaze | D | ✅ Card | A Ready enemy within 9" makes an Agility test, failed: it loses its Ready marker. |
| The Horror | S | ✅ Card | The selected enemy within 12" takes a Nerve Check. |
| Leech Essence | S | ✅ Card | A hit S3, AP -1, L1 on the selected enemy within 12". |
| Paroxysm | S/C | ✅ Card | The selected enemy within 9": BS and WS 6+ while in effect. |
| Aura Of Despair | F/C | ✅ Card | Enemies Cl -1 while in effect. |
| Hallucinations | S | ✅ Card | The selected enemy within 12" makes a Wil check, failed: Insanity. |
| Crush | F | ⚠️ Partly | Cast only. |
| Force Field | S/C | ⚠️ Partly | Cast only. |
| Terrible Truths | S | ✅ Card | The selected enemy within 6" makes a Wil check, failed: Insanity. |
| Psychotic Lure | S | ⚠️ Partly | Cast only. |
| Deceitful Thoughts | D | ✅ Card | The selected enemy within 6" makes a Wil check. Its outcome is played by hand. |
| Cacophony Of Silence | S/C | ✅ Card | Enemies re-roll their ranged hits. |
| A Perfect Void | F/C | ✅ Card | Enemies within 10" count it as at Long range. |
| Eternal Slumber | S | ✅ Card | A Seriously Injured enemy within 3" goes Out of Action. |
| Scouring | F/C | ✅ Card | Armed with the Scouring weapon (Template, Blaze (5+)) while in effect. |
| Levitation | F/C | ✅ Card | M +3 while in effect. |
| Warp Strength | F/C | ✅ Card | S +2 and melee weapons L +1 while in effect. |
| Warp Shield | S | ✅ Card | The Wyrd and friends within 3": Sv +1 until the end of the round. |
| Maddening Visions | S | ✅ Card | An enemy ending its activation within 3" this round gains Insanity. |

---

## Gang / Subtype rules

| Rule | Status | What the card does |
| --- | --- | --- |
| House Escher | ✅ Card | Agility tests re-roll a natural 1. |
| Wyld Hunt | ✅ Card | Agility tests re-roll any failed test. |
| Chymist Cult | ✅ Card | Toxin weapons gain Shred (6+). |
| House Delaque | ✅ Card | With 2 or more friends within 3": Ld and Wil +1, updated as models move. |
| House Goliath | ✅ Card | +1 S on the charge. |
| Palanite Enforcers | ✅ Card | Group Activation is a Free action while Active. |
| Outcasts | ✅ Card | The Leader within 6": no Nerve Checks, and no Willpower check needed against Fearsome. |
| Genestealer Cults | ✅ Card | +1 to Coup de Grace. |
| Hanger-ons | ✅ Card | No gang rules for them. |
| Spyrers | ✅ Card | Two activations a round. |
| Mounted | ✅ Card | M is never changed by wargear or Wyrd powers. |
