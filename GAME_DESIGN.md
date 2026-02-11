# Catch Me If You Can - Game Design Document

## 1. CORE CONCEPT

### Game Identity

- **Game Title:** Catch Me If You Can
- **Elevator Pitch:** A chaotic tag/chase game where one player is "It" and must tag all runners before time runs out — with wacky powerups, themed maps, and tons of unlockable cosmetics.
- **Genre:** Tag/Chase + Party Game
- **Theme/Setting:** Cartoon/Stylized — bright, colorful, exaggerated
- **Core Fantasy:** Be the ultimate runner who never gets caught, or the unstoppable tagger who catches everyone.
- **Target Audience:** 8-12 years old

### Inspiration & Differentiation

- **Inspirations:** Roblox Tag, Freeze Tag, Floor is Lava, Among Us (social deduction aspects), Fall Guys (chaotic party feel)
- **What makes it unique:** Powerup system that creates wild moments — invisibility, freeze traps, speed boosts, and teleportation combined with themed maps that have unique interactive elements
- **The Hook:** Quick rounds with satisfying chases, unlockable cosmetics (skins, trails, tag effects), ranked progression, and rotating map pool that keeps every round feeling fresh

---

## 2. GAMEPLAY LOOP

### Moment-to-Moment

- **Primary Activity:** Running, dodging, chasing, using powerups strategically
- **Player Actions:** Sprint, dodge, use powerup, tag (tagger), hide, juke (runner)
- **Typical Session:** 10-20 minutes (3-5 quick rounds)

### Objectives & Goals

- **Main Objective:**
  - **Tagger:** Tag all runners before the timer expires
  - **Runner:** Survive until the timer runs out without being tagged
- **Game Structure:** Round-based with lobby intermissions
- **Win Conditions:**
  - Tagger wins if all runners are tagged
  - Runners win if at least one runner survives the full round
- **Lose Conditions:**
  - Tagger loses if time expires with runners remaining
  - Individual runners lose when tagged (become spectators or frozen)
- **Secondary Goals:** Earn coins, complete challenges, climb ranked leaderboard, unlock cosmetics

### Challenge & Difficulty

- **Challenge Sources:** Player skill (movement, juking, map knowledge), powerup timing, tagger strategy
- **Difficulty Scaling:** More taggers added as player count increases; maps have varying difficulty
- **Tag/Elimination System:** Tagged runners are frozen in place for a short duration, then become spectators (or can be freed by other runners in Freeze Tag mode)

---

## 3. WORLD DESIGN

### Map Structure

- **Map Count:** 6+ themed maps (rotating selection each round)
- **General Layout:** Enclosed arenas with obstacles, corridors, hiding spots, and vertical elements
- **Approximate Map Size:** Medium — large enough for chases but small enough to prevent endless running

### Maps

1. **Playground Panic** — A giant colorful playground with slides, monkey bars, tunnels, and spinning platforms. Starter-friendly layout.
2. **Rooftop Rumble** — City rooftops connected by bridges, ziplines, and jump pads. Vertical gameplay with fall risk.
3. **Jungle Jamboree** — Dense jungle with vines to swing on, river crossings, and hidden cave passages.
4. **Haunted Hallways** — Spooky mansion with dark corridors, secret doors, and rooms that shift and change.
5. **Space Station Scramble** — Low-gravity zones, airlocks, conveyor belts, and teleporter pads.
6. **Candy Kingdom** — Giant candy-themed landscape with bouncy gumdrops, sticky caramel zones, and lollipop towers.

### Key Locations (Per Map)

- **Spawn Area** — Where runners scatter at round start (tagger spawns after countdown)
- **Powerup Pads** — Glowing spots where powerups spawn periodically
- **Shortcuts** — Map-specific pathways that require timing or skill to use
- **Danger Zones** — Areas that slow you down or push you around (conveyor belts, slippery floors, bounce pads)

### Environmental Features

- **Interactive Objects:** Doors that can be slammed shut, bridges that collapse, moving platforms, ziplines, trampolines
- **Environmental Hazards:** Slippery ice patches, sticky floors, wind gusts, spinning obstacles
- **Map Gimmicks:** Each map has a unique mechanic (low gravity, shifting rooms, darkness, etc.)

---

## 4. PLAYER SYSTEMS

### Movement

- **Basic Movement:** Walk and sprint (unlimited sprint for fun factor)
- **Special Movement:**
  - **Double Jump** — All players get a double jump
  - **Slide** — Quick slide under obstacles and through gaps
  - **Wall Jump** — Bounce off walls for quick direction changes (select maps)
- **Movement Speeds:**
  - Base Walk Speed: 16
  - Base Run Speed: 22
  - Tagger Speed Bonus: +4 (to make chases tense but not instant)
  - Runner gets a 3-second head start before tagger is released

### Tag Mechanics

- **Tag Method:** Tagger touches runner (proximity-based, ~6 stud range)
- **Tag Cooldown:** 1.5 seconds between tags (prevents spam-tagging crowds)
- **Tag Effect:** Tagged runner freezes in place with a fun visual effect (ice block, cartoon stars, etc.)
- **Freeze Duration:** 5 seconds of freeze animation, then becomes spectator
- **Freeze Tag Mode (alternate):** Frozen players can be unfrozen by other runners touching them

### Game Modes

1. **Classic Tag** — One tagger, tag everyone. Tagged = out.
2. **Freeze Tag** — Tagged players freeze in place. Runners can unfreeze allies by touching them. Tagger wins by freezing everyone at once.
3. **Infection** — Tagged runners become taggers too. Last runner standing wins.
4. **Hot Potato** — The "tag" passes to whoever you touch. Whoever is "It" when the timer hits zero loses.

---

## 5. POWERUP SYSTEM

### Powerup Spawning

- Powerups spawn on designated pads around each map
- New powerup spawns every 12-15 seconds
- Only one powerup can be held at a time
- Collected by walking over the pad

### Powerup Types

| Powerup | Icon Color | Duration | Effect |
|---------|-----------|----------|--------|
| **Speed Boost** | Yellow | 5s | +50% movement speed |
| **Invisibility** | Light Blue | 4s | Become invisible (faint shimmer visible up close) |
| **Shield** | Green | One use | Blocks one tag attempt, then breaks |
| **Freeze Trap** | Cyan | Place | Drop a trap that freezes the tagger for 3s if stepped on (runner only) |
| **Teleport** | Purple | Instant | Teleport to a random location on the map |
| **Mega Jump** | Orange | 8s | Triple jump height for vertical escape |
| **Smoke Bomb** | Gray | Instant | Creates a cloud that blocks vision in an area for 4s |
| **Magnet** | Red | 6s | Tagger-only: pulls nearest runner slightly toward you |

### Powerup Balance

- Runners and taggers can both pick up powerups
- Some powerups are role-specific (Freeze Trap = runner only, Magnet = tagger only)
- Universal powerups (Speed Boost, Teleport, Mega Jump, Smoke Bomb) work for both roles

---

## 6. PROGRESSION

### Experience & Leveling

- **XP Sources:**
  - Surviving a round: 50 XP
  - Tagging a player: 20 XP per tag
  - Winning as runner: 100 XP
  - Winning as tagger (tag all): 150 XP
  - Using powerups: 5 XP per use
  - Completing challenges: varies
- **Level Cap:** 100 (with prestige system after)
- **Level Rewards:** Coins, cosmetic unlocks, title unlocks at milestone levels

### Ranked System

- **Ranks (lowest to highest):**
  1. Bronze (0-299 trophies)
  2. Silver (300-599 trophies)
  3. Gold (600-999 trophies)
  4. Platinum (1000-1499 trophies)
  5. Diamond (1500-1999 trophies)
  6. Champion (2000+ trophies)
- **Trophy Gain/Loss:**
  - Win as runner: +15 trophies
  - Win as tagger: +20 trophies
  - Lose: -10 trophies
  - Participation (no win): +3 trophies
- **Seasonal Resets:** Soft reset each season (keep 50% of trophies)

### Challenges

- **Daily Challenges (3 per day):**
  - "Tag 5 players" — 50 Coins
  - "Survive 3 rounds" — 50 Coins
  - "Use 10 powerups" — 30 Coins
  - "Win a round as tagger" — 75 Coins
- **Weekly Challenges (3 per week):**
  - "Win 10 rounds" — 200 Coins
  - "Play on 4 different maps" — 150 Coins
  - "Tag 30 players total" — 250 Coins

### Achievements/Badges

| Achievement | Requirement | Reward |
|------------|-------------|--------|
| First Tag | Tag your first player | 25 Coins |
| Survivor | Survive 10 rounds | Speed Trail unlock |
| Tag Master | Tag 100 players total | "Tag Master" title |
| Ghost Runner | Win 5 rounds without being seen | Invisibility skin effect |
| Marathon | Run 10,000 total studs | Runner's Sneakers skin |
| Untouchable | Win 3 rounds in a row as runner | Diamond Trail unlock |
| Exterminator | Tag all runners in under 30 seconds | "Lightning" tag effect |
| Social Butterfly | Play 50 rounds | 500 Coins |
| Map Explorer | Play on every map at least once | 200 Coins |
| Champion | Reach Champion rank | Exclusive Champion skin |

---

## 7. ECONOMY

### Currencies

| Currency | Icon | Earned From | Spent On |
|----------|------|-------------|----------|
| Coins | Gold coin | Rounds, challenges, achievements, daily login | Skins, trails, emotes, tag effects |
| Gems | Blue gem | Premium (Robux), rare achievements | Exclusive cosmetics, battle pass |

### Earning Rates

- **Per Round (average):** 15-30 Coins
- **Daily Challenges:** ~150 Coins total
- **Weekly Challenges:** ~600 Coins total
- **Daily Login Bonus:** 25-100 Coins (scales with streak)

### Coin Prices

| Category | Price Range |
|----------|------------|
| Common Skins | 100-250 Coins |
| Uncommon Skins | 500-750 Coins |
| Rare Skins | 1,000-2,000 Coins |
| Epic Skins | 3,000-5,000 Coins |
| Legendary Skins | 8,000-15,000 Coins |
| Trails | 200-2,000 Coins |
| Tag Effects | 300-3,000 Coins |
| Emotes | 150-1,500 Coins |

---

## 8. MONETIZATION

### Gamepasses

| Name | Price (R$) | Effect |
|------|------------|--------|
| VIP Pass | 199 | 2x coin earnings, VIP nameplate, exclusive VIP emote |
| Emote Pack | 99 | Unlock 10 premium emotes |
| Trail Pack | 149 | Unlock 5 premium trails |
| Radio Pass | 49 | Play music in lobby |

### Developer Products

| Name | Price (R$) | Effect |
|------|------------|--------|
| Gem Pack (Small) | 49 | 100 Gems |
| Gem Pack (Medium) | 99 | 250 Gems |
| Gem Pack (Large) | 249 | 700 Gems |
| Coin Boost (1hr) | 25 | 2x coins for 1 hour |

### Battle Pass (Seasonal)

- **Free Track:** Basic rewards every 5 levels (coins, common cosmetics)
- **Premium Track (Gems):** Exclusive skins, trails, tag effects, emotes at every level
- **Season Length:** 30 days
- **Levels:** 30 tiers, unlocked via XP

### Free-to-Play Balance

- All gameplay features accessible for free
- Paid content is cosmetic only (no gameplay advantage)
- Free players can earn all non-exclusive cosmetics through gameplay
- Premium exclusives are visual prestige only

---

## 9. COSMETICS

### Skins

- Full character skins that change the player's appearance
- Categories: Animals, Robots, Food, Fantasy, Holidays, Memes
- Rarity tiers: Common, Uncommon, Rare, Epic, Legendary

### Trails

- Visual effects that follow the player while running
- Types: Sparkles, Fire, Ice, Rainbow, Lightning, Hearts, Stars, Smoke

### Tag Effects

- Visual/sound effect when a tagger tags a runner
- Types: Explosion, Freeze Burst, Lightning Strike, Confetti, Slime Splash

### Emotes

- Animations players can perform in lobby or after winning
- Types: Dances, taunts, celebrations, silly poses

### Victory Effects

- Special effect that plays when you win a round
- Fireworks, confetti cannon, spotlight, trophy animation

---

## 10. MULTIPLAYER

### Server Structure

- **Players per Server:** 12 (optimal for chase gameplay)
- **Minimum to Start:** 2 players (1v1 tag)
- **Optimal Count:** 6-12 players
- **Solo Play:** Practice mode against AI runners (limited rewards)

### Social Features

- **Party System:** Invite friends to queue together (always same server)
- **Spectator Mode:** Tagged players spectate remaining runners with free camera
- **Emote Wheel:** Express yourself in lobby between rounds
- **Leaderboards:** Global, friends-only, and seasonal rankings
- **Private Servers:** Host games with custom settings (player count, powerups on/off, map selection)

---

## 11. USER INTERFACE

### HUD Elements

- **Top Bar:** Coins display, Gems display, player level/XP bar
- **Round Timer:** Large centered countdown during rounds
- **Role Indicator:** "You are the TAGGER!" / "RUN!" banner at round start
- **Player Count:** "Runners Remaining: 5/8" display
- **Powerup Slot:** Current held powerup icon (bottom center)
- **Minimap:** Small corner map showing general player positions (tagger sees runner dots, runners see tagger dot)

### Key Screens

- **Lobby:** Player hub between rounds with cosmetic preview, shop access, leaderboards
- **Shop:** Tabs for Skins, Trails, Tag Effects, Emotes, with preview
- **Inventory/Locker:** Equip owned cosmetics
- **Leaderboards:** Ranked standings, friends list, seasonal rankings
- **Battle Pass:** Season progress and reward track
- **Settings:** Music, SFX, controls, sensitivity
- **Challenges:** Daily/Weekly challenge tracker with progress bars

### Notifications

- "You were tagged!" — center screen flash
- "3 runners remaining!" — top announcement
- "[Player] tagged [Player]!" — kill feed style at top right
- "New powerup available!" — subtle indicator
- "Challenge Complete!" — popup with reward
- "Level Up!" — celebratory full-screen popup

### Onboarding

- **First Game:** Guided tutorial round with prompts
  - "WASD/Joystick to move!"
  - "Press SPACE to jump!"
  - "Walk over glowing pads to collect powerups!"
  - "Press E to use your powerup!"
  - "Don't let the tagger catch you!"
- Short and non-intrusive — players learn by playing

---

## 12. VISUAL STYLE

- **Art Style:** Bright, exaggerated cartoon — chunky shapes, bold outlines, bouncy animations
- **Color Palette:** Vibrant primaries — electric blue, hot pink, lime green, sunny yellow
- **Character Design:** Simplified Roblox characters with oversized heads and expressive faces
- **Map Aesthetic:** Each map has a distinct color theme and props that match the setting
- **VFX:** Lots of particle effects — sparkles, speed lines, impact bursts, trails
- **Animation Style:** Snappy, exaggerated — big windups, stretchy movements, squash and stretch

---

## 13. AUDIO

- **Background Music:** Upbeat, energetic electronic/pop — changes tempo when tagger is near
- **Chase Music:** Intensifies as tagger gets closer to a runner
- **Sound Effects:**
  - Tag sound (satisfying "bonk" or "zap")
  - Powerup collect (sparkle chime)
  - Freeze sound (ice crackle)
  - Round start horn
  - Victory fanfare
  - Footstep variations per surface
- **Voice Lines:** None (text-based communication only)

---

## 14. TECHNICAL REQUIREMENTS

### Performance

- **Target Platforms:** PC, Mobile, Console (all Roblox platforms)
- **Server Capacity:** 12 players max
- **Optimization Focus:** Smooth movement/physics, minimal lag for tag detection

### Data Persistence

- **Saved Data:** Coins, Gems, XP/Level, Rank/Trophies, owned cosmetics, equipped cosmetics, stats, settings, challenge progress, achievements
- **System:** Roblox DataStore with retry/backoff pattern
- **Anti-Cheat:** Server-authoritative tag detection, speed validation, rate limiting on all remotes

---

## 15. DEVELOPMENT PRIORITIES

### Phase 1: MVP (Core Tag Loop)

1. [ ] Round system (Lobby → Countdown → Playing → Results → Intermission)
2. [ ] Tagger/Runner role assignment and spawning
3. [ ] Tag detection (server-authoritative)
4. [ ] Basic movement (sprint, double jump)
5. [ ] Round timer and win/lose conditions
6. [ ] Basic HUD (timer, role indicator, player count)
7. [ ] Data persistence (coins, stats, settings)
8. [ ] One starter map (Playground Panic)

### Phase 2: Powerups & Maps

1. [ ] Powerup spawning system
2. [ ] Speed Boost, Shield, Invisibility, Teleport powerups
3. [ ] Freeze Trap, Mega Jump, Smoke Bomb, Magnet powerups
4. [ ] Powerup HUD slot and activation
5. [ ] Rooftop Rumble map
6. [ ] Jungle Jamboree map
7. [ ] Map rotation/voting system

### Phase 3: Progression & Economy

1. [ ] XP and leveling system
2. [ ] Coin earning per round
3. [ ] Shop system (skins, trails, tag effects, emotes)
4. [ ] Ranked/Trophy system
5. [ ] Daily and weekly challenges
6. [ ] Achievement/Badge system
7. [ ] Daily login rewards

### Phase 4: Game Modes & Maps

1. [ ] Freeze Tag mode
2. [ ] Infection mode
3. [ ] Hot Potato mode
4. [ ] Haunted Hallways map
5. [ ] Space Station Scramble map
6. [ ] Candy Kingdom map
7. [ ] Game mode voting in lobby

### Phase 5: Social & Monetization

1. [ ] Gamepasses (VIP, Emote Pack, Trail Pack, Radio)
2. [ ] Gem currency and premium shop
3. [ ] Battle Pass system (seasonal)
4. [ ] Party system (play with friends)
5. [ ] Private server support with custom settings
6. [ ] Spectator camera improvements
7. [ ] Leaderboard system

### Phase 6: Polish & Launch

1. [ ] Tutorial/onboarding flow
2. [ ] Audio system (music, SFX, proximity chase music)
3. [ ] Visual polish (VFX, animations, UI animations)
4. [ ] Mobile controls optimization
5. [ ] Performance optimization and load testing
6. [ ] Balance pass on powerups, speeds, and timing
7. [ ] Bug fixing and QA
