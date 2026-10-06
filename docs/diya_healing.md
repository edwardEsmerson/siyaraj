# Diya healing

Lighting a new main-route checkpoint diya restores 1 HP, capped at Siya's
configured maximum. This applies to the forest trail, river and palace. The
player's `heal` API owns the health change and emits `health_changed` only when
health increases. Healing does not revive Siya or extend damage protection.

The main routes already divide encounters with explicit grounded E interactions.
They retain lit diya names across death and campaign Continue. A one-HP reward
therefore gives players a reason to secure each stretch, without rewarding idle
waiting or restoring all three starting HP after every encounter. Timed
regeneration would let players wait out damage between encounters and during
boss fights, so it was not chosen. Enemy placement and boss tuning are unchanged.

Activation records the lit name before requesting healing. Repeat presses,
walking away and returning, death/retry, and disk restoration cannot award it
again. Lighting at full health still consumes the opportunity. A new run resets
checkpoint progress and restores eligibility. Existing saves need no migration;
already-lit names count as already used.

Forest side-room lamps remain local respawn markers without a healing reward.
Their lit state resets on every visit, and the campaign save only records trail
lamps. Including them would allow portal re-entry or Continue to renew healing.
Keeping them unchanged avoids adding save fields or changing detour checkpoints.
Existing full-health death retries, fresh boss entries and Swaminathan's full
phase/defeat healing remain intact.

A successful heal fills the existing HUD heart and displays a green `+1 HP`
burst above Siya for 0.9 seconds using the existing effect and font. At full
health the diya still lights with its usual sound and Siya's lighting pose;
there is no false `+1 HP` message. Legacy combat-status labels are hidden by the
campaign HUD, so they are not used as healing feedback.

`tests/diya_healing_check.gd` exercises real input and collisions in all three
levels, full-health consumption, injury, repeated presses, return to an earlier
lamp, health signal emission, feedback, death/retry, disk Continue, configured
max-health caps, invalid heal amounts, dead-player rejection, and two visits to
a detour lamp. Existing checkpoint, campaign save and boss suites cover their
unchanged contracts. Run the suite with `--capture-healing` in a graphical Godot
session to save a feedback frame to `/tmp/siyaraj-diya-healing.png`.
