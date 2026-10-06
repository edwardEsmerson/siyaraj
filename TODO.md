# Remaining work

Prioritised from the playtest recording on 2026-10-07. Repeated feedback is merged; reported bugs need verification. Work through each priority in the order listed.

## P0 · Finish the playable game

- [ ] Give Dhoomketu his sprites and animations. Explicitly called out as very high priority.
- [ ] Fix Swaminathan's animations. He appears to stay on one frame; check whether existing animations are failing before creating more.
- [ ] Fix Swaminathan's roar attack. Check the complaint about it spawning at Siya's feet while she attacks. Give players enough warning and room to respond.
- [ ] Complete every boss defeat sequence: death animation → exit opens → player leaves → curtains transition → story dialogue. Khara currently jumps straight into dialogue.
- [ ] Finish the ending. Make the final dialogue, escape through the gates, and victory screen flow correctly. Add victory art; decorative fireworks can follow later.
- [ ] Add save/load and Continue. Decide what progress checkpoints preserve, then verify dying, quitting, and reopening the game.

## P1 · Make combat readable and remove interruptions

- [ ] Replace placeholder attack shapes with sprites. Cover enemy projectiles, Khara's crackers, boss hazards, and impact effects. Start with attacks players must recognise to dodge.
- [ ] Reduce Robin's pop-ups. Keep introductions to new enemies and mechanics; remove repeated advice during ordinary encounters.
- [ ] Fix Robin's dialogue portrait. The recording reports multiple sprite frames appearing together.
- [ ] Teach players to dash through homing missiles. Add one clear hint at the first relevant encounter.
- [ ] Check jumps that appear to require coyote time. Adjust problematic platform spacing after playtesting.
- [ ] Remove the player-facing R restart shortcut. Keep any developer restart behaviour restricted to debug use.
- [ ] Use curtain transitions when Siya dies, including during boss fights.

## P2 · Improve level pacing and presentation

- [ ] Add and redistribute enemies. The feedback asks for roughly double the enemies and more variety. Tune each section rather than doubling every encounter automatically.
- [ ] Fix diya sprites/textures. Also check why another diya sometimes cannot be lit.
- [ ] Fix palace scenery placement. Correct misplaced bricks and the oversized or protruding window/background section.
- [ ] Add core audio. Prioritise damage, attacks, boss cues, diya lighting, and victory, then music and ambience.
- [ ] Fix the heart glyph in the credits. Replace the unsupported emoji with a sprite or supported glyph.
- [ ] Add remaining character/environment animations once the boss animation gaps are resolved.

## P3 · Optional additions

- [ ] Choose a healing mechanic. Diya healing and timed regeneration were suggestions. Pick one only after testing difficulty; avoid adding both by default.
- [ ] Add rebindable controls. The recording explicitly treats this as a maybe.
- [ ] Add interactive scenery, such as bells that make a sound when hit.
- [ ] Reuse the title-screen fireworks in the palace and add decorative victory effects.

## Playtest order

Finish Dhoomketu, Swaminathan, boss transitions, the ending, and saves first. Then do one full playthrough before increasing enemy density or adding healing, because those decisions depend on how the finished encounters play.
