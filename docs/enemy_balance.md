# Regular enemy combat

Guards, brutes, flyers and ground shooters resist stagger for 1.4 seconds after
being staggered. Follow-up hits still reduce health and show impact feedback,
but do not restart hurt timers, cancel the next attack or add knockback. The
resistance timer starts on a successful stagger; extra hits do not refresh it.

A guard's first wind-up can still be interrupted. Active melee strikes finish
through nonlethal hits. Guards recover from stagger in 0.12 seconds so they can
counter the campaign's faster lash. Ground shooters also stagger for 0.12 seconds
and charge for 0.55 seconds instead of 0.65 seconds. Brutes additionally brace
throughout their orange wind-up, so attacking into a heavy swing trades damage
unless Siya dodges or moves out of reach. Brutes retain six health, two damage
per strike, locked facing, a 0.7-second wind-up and a 0.95-second recovery.

Hits during melee recovery or ranged reload deal damage without cancelling or
extending those phases. Dodge the tell, then attack during recovery. Lethal
damage always defeats the enemy and cancels its melee attack; projectiles that
have already been fired retain their existing lifetime and collision rules.
All enemy damage still uses Siya's `take_damage` API and respects dash i-frames.

`tests/enemy_pressure_check.gd` exercises repeat-hit counterattacks, stagger
expiry, real campaign lash spam against a guard and brute, a dash through the
brute's armored strike, and a real recovery punish. The existing enemy and cast suites also check
damage, timing, defeat and animations. Manual tuning should use the Guard,
Brute, Flyer and Shooter encounters in `scenes/dev/sandbox.tscn`.
