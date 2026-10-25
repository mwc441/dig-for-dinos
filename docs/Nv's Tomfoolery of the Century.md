# Nv's Tomfoolery of the Century (dig for dinos balancing)

ok so this is basically everything about how the economy works and why i set it up like this. if a number looks random its prolly not, read why first before u go changing shit lol

all the designing and the calls on how stuff should work was me. i used claude for the long boring math, running the sims, and cleaning this doc up, then i went thru it and checked it. oh no Mr. Anti AI used AI as a tool! How could he!!!!

everything lives in `ReplicatedStorage/ReplicatedConfigs` except one thing in `Dirt.lua` (pile size health, its further down)

---

## the main rules, read these or ur gonna be confused

1. **dig power is forever, cash isnt.** dig power never resets, not even on rebirth. cash gets spent AND wiped every rebirth. so we can throw cash around but gotta be stingy with dig power or ppl just skip the whole game
2. **dig power is what actually gates u.** zones are locked by pile health and u beat pile health with dig power. cash just buys stuff that makes ur dig power go up faster (shovels, rebirths, training speed)
3. **zone > rarity.** every zone's dinos should beat the last zone's. like a rare from volcano should shit on a legendary from zone 1 cuz it was way harder to get
4. **mutations can beat rarity.** void or flame mythical beats a plain secret, gold mythical doesnt. so mutations actually mean something
5. **sets are quick, walls are the grind.** zones 1-3 are one set, 4-6 are another, 7 is the first solo zone. going thru a set is fast, getting into the next one is the grind
6. **cheap early, expensive late.** first stuff is like a minute of income, endgame stuff is an hour+. cheap early so new ppl feel like theyre going somewhere, expensive late so theres always something to chase

---

## pacing

what im going for:
- get to zone 7 with a decent team in **less than a day** of playtime
- get everything perfect (all rebirths, index, secrets) in **more than a day**
- most ppl only play like 20 min total so the first set needs to feel good fast

sim results (solo, no stealing, no p2w):

| milestone | when |
|---|---|
| zone 2 | ~2 min |
| zone 3 | ~7 min |
| zone 4 (first wall) | ~35 min |
| zone 5 | ~1 h |
| zone 6 | ~2 h |
| zone 7 (second wall) | ~6.5 h |
| all 9 shovels | ~7 h |
| zone 7 secrets diggable in ~30 hits ("win") | ~23 h |
| all 15 rebirths | 30 h+ |

real ppl will be a lil faster than this cuz stealing, the hourly secret piles and fighting over mythicals all give extra money the sim doesnt count. also this was simmed before the last rarity nerf so it might be a lil slower now idk

p2w vs not:

| player | zone 7 | win |
|---|---|---|
| free to play | 6.4 h | 23 h |
| cash 2x | 5.6 h | 19 h |
| vip (2x cash, 2x dig) | 3.5 h | 12.5 h |
| cash 32x | 2.4 h | 10 h |
| full whale (32x + vip + dig 2x) | 1 h | 3.3 h |

whales beating it in a few hours is normal for steal games. nobody fully skips it tho, u still gotta train thru the walls

---

## zones

| zone | name | set | health multi | jump | income multi |
|---|---|---|---|---|---|
| 1 | grassland | set 1 | 1 | - | 1 |
| 2 | farm | set 1 | 5 | 5x | 2 |
| 3 | aztec | set 1 | 25 | 5x | 4 |
| 4 | desert | set 2 | 1,000 | **40x wall** | 1 |
| 5 | snow | set 2 | 4,000 | 4x | 2 |
| 6 | volcano | set 2 | 16,000 | 4x | 4 |
| 7 | fantasy | solo | 650,000 | **40x wall** | 1 |

- health multi is in `DirtSpawnerDef`, income multi is in `ZoneDef`
- income multi is just the lil bonus INSIDE a set (1/2/4). the big jump between sets is baked into each dinos base income so the index shows the real number
- zones after 7 are all solo, prolly like 10-20x health each

---

## dinos + money

money per second = **base income × zone multi × mutation × size**

base income (zones 1-3):

| rarity | per sec |
|---|---|
| common | 10 |
| uncommon | 30 |
| rare | 90 |
| epic | 270 |
| legendary | 800 |
| mythical | 2,500 |
| secret | 10,000 |

- each tier is 3x the one before
- zones 4-6 dinos are **x12**, zone 7 dinos are **x150** (already in their base income in `DinosaurDef`)
- so like volcano rare = 4,320/s vs zone 1 legendary = 800/s. void mythical = 12,500/s vs plain secret = 10,000/s. works how i want it

mutations:

| mutation | multi | chance |
|---|---|---|
| normal | 1x | 89.5% |
| gold | 2x | 7.5% |
| void | 5x | 2.5% |
| flame | 10x | 0.5% |
| admin | 25x | admin weather only |

gold/void/flame weather doubles that mutations luck while its going

which rarity a dino is goes by how unique it is. if its basically a copy of something we already got (all the trex lookalikes) its common/uncommon. one of a kind stuff (only flyer, only swimmer, giant claws) goes high. memes like tung and ballerina stay mid so the top tiers arent just troll dinos

---

## dirt piles

### health
pile health = **base health × zone health multi × size^1.5**

| pile | base health |
|---|---|
| common | 100 |
| uncommon | 150 |
| rare | 250 |
| epic | 400 |
| legendary | 650 |
| mythical | 1,100 |
| secret | 8,000 |

every pile in every zone (no size):

| zone | common | uncommon | rare | epic | legendary | mythical | secret |
|---|---|---|---|---|---|---|---|
| 1 | 100 | 150 | 250 | 400 | 650 | 1.1K | 8K |
| 2 | 500 | 750 | 1.25K | 2K | 3.25K | 5.5K | 40K |
| 3 | 2.5K | 3.75K | 6.25K | 10K | 16.25K | 27.5K | 200K |
| 4 | 100K | 150K | 250K | 400K | 650K | 1.1M | 8M |
| 5 | 400K | 600K | 1M | 1.6M | 2.6M | 4.4M | 32M |
| 6 | 1.6M | 2.4M | 4M | 6.4M | 10.4M | 17.6M | 128M |
| 7 | 65M | 97.5M | 162.5M | 260M | 422.5M | 715M | 5.2B |

health ÷ ur dig power = how many hits it takes (1 hit a sec). when u can do a zones common in like 10 hits thats when u can actually play there

secret piles are like 7x a mythical pile on purpose. its a reach goal and the long dig gives ppl time to slap u off it

### size
| size | chance | health |
|---|---|---|
| 1x | 90% | 1x |
| 1.3-1.6x | 5% | ~1.5-2x |
| 1.6-1.9x | 3% | ~2-2.6x |
| 1.9-2.2x | 2% | ~2.6-3.3x |

size also makes the dino make more money. big piles used to have the same health as normal ones so everyone just went for those. now theyre tankier than their size (size^1.5) but not crazy. change it with `DirtDef.SizeHealthExponent` (1 = health matches size, 0 = turn it off). the math is in `ServerScriptService/Services/Digging/Dirt.lua`

### what u get from a pile
every pile rolls its own rarity or higher and each step up is way rarer. this is the gambling part, the roll animation is lowk everything

| pile | own rarity | +1 | +2 | +3 | +4 | +5 | +6 |
|---|---|---|---|---|---|---|---|
| common | 77 | 19 | 3.4 | 0.5 | 0.1 | 0.025 | 0.006 |
| uncommon | 77 | 19 | 3.4 | 0.5 | 0.1 | 0.03 | |
| rare | 78 | 18 | 3.2 | 0.6 | 0.15 | | |
| epic | 80 | 16.5 | 2.8 | 0.7 | | | |
| legendary | 86.5 | 11.5 | 2 (secret) | | | | |
| mythical | 92 | 8 (secret) | | | | | |
| secret | 100 | | | | | | |

top piles are capped (legendary 2% secret, mythical 8% secret) so secrets dont get handed out like candy

### what spawns where
deeper zones in a set spawn better piles, thats the main reason going deeper pays more

| zone | common | uncommon | rare | epic | legendary | mythical | secret |
|---|---|---|---|---|---|---|---|
| 1 & 4 | 74 | 20.5 | 4.4 | 0.8 | 0.15 | 0.025 | 0.008 |
| 2 & 5 | 60 | 27 | 9.5 | 2.6 | 0.6 | 0.1 | 0.016 |
| 3 & 6 | 48 | 31 | 15 | 4.8 | 1.2 | 0.25 | 0.03 |
| 7 | 54 | 28 | 12.5 | 4 | 1 | 0.18 | 0.02 |

zone 7 secrets are low on purpose so the dragon stays rare as shit

### real odds per pile u dig

| zone | epic | legendary | mythical | secret |
|---|---|---|---|---|
| 1 & 4 | 1 in 40 | 1 in 172 | 1 in 780 | 1 in 2,790 |
| 2 & 5 | 1 in 20 | 1 in 69 | 1 in 300 | 1 in 1,245 |
| 3 & 6 | 1 in 13 | 1 in 40 | 1 in 158 | 1 in 705 |
| 7 | 1 in 15 | 1 in 47 | 1 in 196 | 1 in 884 |

mythicals were spawning way too much at first (like 1 in 42 in zone 3, i kept pulling them) so everything above rare got nerfed. good shit should feel rare

### guaranteed piles (1 per server, random zone, says it in chat)
| pile | every |
|---|---|
| legendary | 20 min |
| mythical | 45 min |
| secret | 60 min |

the hourly secret is how most ppl will get secrets, whole server fights for it. if it spawns in zone 1-3 newer ppl actually got a shot at a trex

---

## shovels + dig power

training at ur excavation gives dig power = shovel power × boosts, once a sec (faster with training speed)

| shovel | power per dig | cost |
|---|---|---|
| wooden | 1 | u start with it |
| stone | 2 | 250 (cheap for the tutorial) |
| bronze | 4 | 50K |
| iron | 8 | 500K |
| steel | 16 | 3M |
| ruby | 32 | 40M |
| diamond | 64 | 150M |
| obsidian | 128 | 1.5B |
| infernal | 256 | 10B |
| omega (robux) | 512 | robux |

- every shovel doubles ur power
- early ones cost less than a minute of income, endgame ones like 30-60 min. thats the point
- the new fantasy shovel lollypop is adding: im thinking **512 power, 75B**, as the zone 7 goal

dig power from 5 min of training (no rebirths or gamepasses):

| shovel | no speed upgrades | max speed |
|---|---|---|
| wooden | 300 | 900 |
| steel | 4.8K | 14.4K |
| diamond | 19.2K | 57.6K |
| infernal | 76.8K | 230.4K |

zone 7 wants like 6.5M dig power to be comfy, thats why rebirths matter so much late

---

## upgrades

| upgrade | levels | what it does | cost |
|---|---|---|---|
| dig training speed | 10 | +0.2 digs a sec each (max 3/sec) | 7.5K → 2.5B |
| speed | 50 | +1.5 walkspeed each (max +75) | 100, then 1.4x more each lvl (lvl 50 is like 1.4B) |
| bear trap limit | 4 | +1 trap each | 1K / 50K / 5M / 500M |
| plot | 5 | +1 dino slot (5 → 10) | 7.5K / 25K / 250K / 1.5M / 20M |

speed resets on rebirth so its cheap enough to just rebuy

---

## rebirths

15 of em. every rebirth wipes ur cash and speed upgrade and gives u:
- **+0.5x cash**
- **1.25x dig power training** (stacks, like 28x by rebirth 15)

| rebirth | cost |
|---|---|
| 1-5 | 2M / 15M / 150M / 750M / 4B |
| 6-10 | 10B / 25B / 40B / 60B / 150B |
| 11-15 | 250B / 400B / 700B / 1.3T / 2T |

rebirths are what get u thru the zone 7 wall. they come like every 1-4 hours so theres always something coming up. the last few are the get everything perfect grind past a day

the dig power boost is just a string id (`"RebirthDigPowerBoost"`) rn cuz its not in `Enums/Boosts` yet. needs a real entry

---

## index, daily, group

- **index:** 4 levels per mutation (normal, gold, void, flame), every claim is +5% cash. 33 dinos total
- **daily:** 1K cash / 500 dig / 5K cash / 10K cash / 3K dig / 25K cash / 8K dig + 50K cash. days 4 and 7 should give dinos once thats in
- **group reward:** 500 cash
- **offline:** 25% of ur income for up to 8 hours

daily is small on purpose so free stuff doesnt compete with the paid packs

## not decided yet / todo

- **omega shovel** at 512 lets u skip most of the game if u buy it early. either price it crazy high or drop it to like 300
- **+1 speed** dev product is kinda useless now with 50 levels. make it give 5 levels
- **scaling packs:** long term packs should scale with how far u are (massive cash = 1 hour of ur income) so theyre always worth it and never break anything. needs code
- **boosts enum:** add `RebirthDigPowerBoost` to `Enums/Boosts`
- **dig power icon** for the daily rewards ui
- **rebirth ui** only shows the cash bonus not the dig power one
- **dino daily rewards** on days 4 and 7
