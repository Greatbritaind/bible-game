# Nain and Route 4 plan (from the story chat, Nov 25, 2026)

**Build notes**
- Baruch #1 is in **Nazareth**, behind Eli's house, not in Nain or on the Tabor road.
- The Burial Cloth already exists as a Witness Case item (`:BURIALCLOTH`). The Exp. Share item exists (`:EXPSHARE`).

## Build kit (ready Nov 25)
The events are already written and tested in the web player; only the maps are missing. **Britain:** make the maps, place an NPC (or a blank event) wherever each one should be, give it the graphic you want, and **name the event exactly as below**. Claude then fills in every page by name, keeps your graphic and spot, and leaves everything else alone. (The script is `tools/rmxp/nain/nain.rb` on the `nazareth` branch.)

**Decided for now (change any time):** the funeral-food family stays, and the son walks around town after the scene (his mother stays home).

| Event name | Map | What it does |
|---|---|---|
| `Running man` | Route 4 | Bump into or talk to him: "You're going to Nain? Go! Go and see!" Then he steps up one tile and runs off west |
| `Tabor sign` | Route 4 | "Mount Tabor, to the north." |
| `Spring woman` | Route 4 | "This spring never runs dry. / Rest a bit. Nain is just across the valley." |
| `Trainer Elon` | Route 4 | Shepherd: Doduo 18, Ponyta 19 |
| `Trainer Keziah` | Route 4 | Spice Trader: Oddish 19, Nidoran♀ 20 |
| `Trainer Shimei` | Route 4 | Tentmaker: Spearow 19, Rattata 20, Nidoran♂ 20 |
| `Trainer Elkanah` | Route 4 | Elder: Nidorino 21, Ponyta 22 |
| `Gate trigger` | Nain | Blank event (no graphic) on each tile across the gate path. Stepping on one starts the arrival scene once |
| `Gate: man`, `Gate: woman`, `Gate: old man` | Nain | The three speakers in the scene |
| `Gate: woman 2`, `Gate: man 2`, `Gate: crowd` | Nain | Extra crowd people (use `Gate: crowd` as many times as you like) |
| `Gate: mother`, `Gate: son`, `Gate: stretcher` | Nain | The widow holding her son on the stretcher |
| `Messenger 1`, `Messenger 2` | Nain | John's two messengers near the gate |
| `Water woman` | Nain | The woman drawing water |
| `Tomb boy` | Nain | The boy near the tombs path (Gastly tip) |
| `Son` | Nain | Walks around town after the scene; gives the Burial Cloth (Witness Case) |
| `Widow` | Widow's house | Gives the Exp. Share once |
| `Mourner`, `Carrier`, `Elisha man`, `Feast woman` | The other 4 houses | Feast woman gives 2 Potions once |
| `Verse left`, `Verse right` | Nain synagogue | Psalm 68:5 and Psalm 30:11 (copy another synagogue map; its Rabbi already heals) |
| `Empty tomb` | The tombs | "This tomb was cut for the widow's son. / It was never used." |

- **How the scene plays:** the player gets a "!" and the crowd turns toward them. The six lines play. Then the screen fades out and back in, and the crowd, mother, son and stretcher are gone. Switch 71 "Nain arrival seen" is now ON.
- **New lines Claude wrote** (please check):
  - Route 4 trainers' lines.
  - The spring woman.
  - Widow after the gift: "He's out walking. He keeps touching everything. / Like he's seeing it all for the first time."
  - Son after the cloth: "The sun feels so warm today. / Have you ever noticed that?"
  - Feast woman after: "Eat up! Today is a feast day."
- **Wild Pokémon and trainers** are written in `tools/rmxp/nain/pbs.txt` and go into PBS once the map numbers exist.
  - Route 4 grass: Ponyta, Doduo, Spearow, Oddish, Nidoran ♀/♂, Rattata, levels 17–21.
  - Tombs: Gastly 50%, Zubat 25%, Rattata 15%, Haunter 10%, levels 18–22.
- **Panel:** "The Quiet Town" turns on once the maps are in. Its steps get ticked off by switch 71.

---

## The story chat's plan (unchanged)

Here’s a full plan for Nain and Route 4. It uses what’s already decided: no Seal House, Gastly in the tombs, the Exp. Share from the widow’s family, John’s two messengers, and the burial cloth for the Witness Case.

The feel

Hushed, then amazed. Nain is a tiny farm village on a hillside (the Hill of Moreh), with a wide view of the valley. The town was about to bury a widow’s only son, and then everything stopped. Think FireRed’s Lavender Town, but with something wonderful happening in the middle of the sadness.

Music: your quietest, most tender town theme.

Route 4: Nazareth to Nain

The shape: east out of Eli’s house, then down the Nazareth hills, then east across the valley floor to Nain. That’s real geography: Nazareth sits high on a ridge, and Nain is across the Jezreel Valley.

Features

Going down the hill: ledges that hop down, so the route feels like a descent. (They also make it one-way, which matches the Tabor road plan for coming back.)
Grain fields on the valley floor. Use tall grass as wheat and barley. Fields are where most of Route 4’s wild Pokémon live.
Mount Tabor in view: a big, round mountain to the north, visible across the valley. A sign: “Mount Tabor, to the north.” That sets up the Tabor road later.
A spring halfway, as a rest stop with one NPC.
Leftovers: one Strength boulder or cut tree hiding an item, since students just got Strength.

Wild Pokémon (grass): Ponyta, Doduo, Nidoran ♀/♂, Spearow, Oddish, Rattata. Open plains, horses and birds. Levels 17–21, since Jotham’s ace is level 21.

Trainers: 4, levels 18–22. Shepherds, farmers and travelers. Reuse classes you already have.

A story moment on the route: a man runs past you from the Nain direction, out of breath.

\bMan: You’re going to Nain? Go! Go and see!
I have to tell my brother. He won’t believe me.

It hints that something happened without spoiling what, and that’s exactly the feeling of arriving just after. Luke 7:17 says the news spread through the whole region.

Nain’s layout
Building or place	What it’s for
The town gate	Where the funeral was stopped (Luke 7:12). The arrival scene happens here
The widow’s house	The Exp. Share and the burial cloth
A small synagogue	The heal point, as in every town
4 more homes	NPCs below. 5 homes total keeps it small
The tombs (east, outside town)	Gastly, plus an empty tomb
The north exit	The one-way Tabor road back toward Capernaum

No market and no gym. Nazareth’s vendor is close enough.

The arrival scene (at the gate)

When the player walks up to the gate the first time, the player stops, and the scene plays.

What they see: two crowds stopped at the gate. Luke says a big crowd came with the teacher and a big crowd came out with the widow (Luke 7:11-12). In the middle there’s a stretcher set down, and a young man sitting up, still wrapped in burial cloth. His mother is holding him.

What they hear:

\bMan: He was dead! We were carrying him out to bury him!
\rWoman: The teacher told her, “Don’t cry.”
Then he touched the stretcher, and we all stopped.
\bOld man: He said, “Young man, get up!” And he did!
\rWoman: A great prophet has come to us!
\bMan: God has come to help his people!

Luke 7:13-16, nearly word for word.

Then the crowd thins out, the mother and son walk home, and the player is free to explore.

NPCs

Outside

John’s two messengers (men), standing near the gate, looking around:
\bMessenger: John the Baptist sent us. He’s in prison.
He wants to ask the teacher, “Are you the one?”
\bMessenger: We heard he was here. Did we miss him again?
(Luke 7:18-20. They’re always one step behind too, like the player.)
A woman drawing water:
\rWoman: We were all crying an hour ago.
Now the whole town is laughing. I can’t stop shaking.
A boy near the path to the tombs (the Gastly tip):
\bBoy: Don’t go to the tombs! Something spooky lives there.
Normal moves go right through it. I tried!

Inside the 5 homes

The widow’s house: the mother and her son.
Mother:
\rMother: My husband died. Then my only son.
I had no one left. And now… look at him.
Please, take this. It helps a Pokémon grow, even resting.
(Received the Exp. Share!)
Son:
\bSon: I was wrapped in this an hour ago.
I don’t need it anymore. Take it.
(The Burial Cloth goes in Ezra’s case.)
The mourner. Families hired mourners to cry at funerals. That’s a real custom of the time (Jeremiah 9:17).
\rMourner: I was paid to cry at the funeral.
Now there’s no funeral. What do I do?
Should I give the money back?
One of the stretcher carriers:
\bCarrier: I was carrying him. My arms were tired.
Then the teacher touched the stretcher, and we just… stopped.
(Luke 7:14 says the carriers stood still.)
The old man who remembers Elisha. This one explains why people shouted “a great prophet.” The prophet Elisha raised a widow’s son at Shunem, right over the hill from Nain (2 Kings 4).
\bOld man: Long ago, Elisha raised a boy back to life.
At Shunem, just over that hill.
Today it happened again, here. Who is this man?
A family getting ready for a party:
\rWoman: The funeral food is still here.
So now it’s a feast! Want some bread?
(Gives a Potion or two.)

The synagogue

The Rabbi heals the party as usual.
Wall verse, left: “A father to the fatherless, a defender of widows, is God.” (Psalm 68:5)
Wall verse, right: “You turned my mourning into dancing.” (Psalm 30:11)
The tombs (east of town)
A small rocky area with cave tombs cut into the hillside.
Wild Pokémon: Gastly (50%), Zubat (25%), Rattata (15%), and Haunter (rare, 10%). Levels 18–22.
The empty tomb. One tomb stands open and empty, with a narrator sign:
This tomb was cut for the widow’s son. It was never used.

It quietly points ahead to Easter, so students who notice will remember it later.

A hidden item in a back corner.
Leaving
The north exit leads to the one-way Tabor road: ledges, trainers, and the rival’s battle (“His own town threw him out. Some Messiah.”).
Panel: after the arrival scene, “Take the Tabor road north, back to Capernaum.”
Baruch #1 (10 caught) could go in Nain or on the Tabor road. Students usually have about 10 by now.

Questions:

Do you want the funeral food family, or would you rather keep Nain quieter with fewer homes?
Should the mother and son be together in their house, or should the son be out walking around town, getting used to being alive?