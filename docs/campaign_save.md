# Campaign persistence

`CampaignSave` owns one versioned JSON file, `user://campaign.json`. New Game
replaces it with the opening stage and clears the in-memory forest and draft
progress. Continue reads and validates it before changing scenes. No save,
malformed JSON, unknown stage/checkpoint, incomplete required bridge state, or an
unsupported version disables Continue. Invalid files are left alone until New
Game replaces them. There is no migration from obsolete versions yet.

The minimal persisted state is the current campaign stage, the last secured
trail diya's authored node name, lit trail diya names, completed forest side
rooms, and the river's placed plank count. Positions are resolved from the
current authored scenes, rather than trusting saved coordinates. Version 1 is
specific to the current routes. Increment `CampaignSave.VERSION` if route or
checkpoint changes make those identifiers unsafe. Unknown JSON fields are
ignored, so additive presentation metadata does not invalidate a save.

Continue restores fresh health, five skyshots, and reset weapon cooldowns, as a
death retry does. Enemies and bosses respawn. Carried planks return to the supply;
placed planks restore their collision bodies before gameplay starts. The bridge
count is preserved even if the last secured diya is before the bridge. A river
diya beyond the bridge requires all four planks in the save.

Forest side-room visits resume at the last secured trail diya. Completed side
rooms survive, but an unfinished visit, its local diya, health/ammo transfer,
and the temporary portal return position do not. This is a deliberate safe
checkpoint policy rather than an arbitrary-position save. Ordinary death still
uses the existing local side-room checkpoint and portal state within the session.

## Writes and developer isolation

New Game and Continue enable the writer. Stage transitions go through
`PlaytestNavigation.start_level`. Diya interactions, bridge placement, and forest
portal completion capture progress immediately. Existing full-level restart
paths capture their reset state; death and checkpoint retry leave the disk save
unchanged. Returning to title captures progress and disables the writer.

Opening the developer menu disables the writer. Launching a developer snapshot
also disables it, including snapshots launched directly during a campaign.
Normal developer menu level launches and standalone F6 scenes do not enable it.
Their in-memory changes cannot overwrite the campaign. Continue clears those
changes and restores the disk state. Tests use separate filenames so they do
not replace a player's campaign save.

Writes flush a sibling `.tmp` file and rename it over the save. Failed writes
retain the prior save and report a warning with `last_error`. Saves happen when
progress changes, so normal application quit and force-close need no shutdown
callback. Unsecured traversal since the last diya is intentionally lost.

## Ending integration contract

`campaign_victory.gd` makes one persistence call on defeat:
`CampaignSave.enter_stage(next_level)`. It records the newly unlocked stage
before aftermath dialogue or result controls. Quitting during forest/river
boss aftermath resumes the next trail, with a fresh loadout. Quitting during
final boss aftermath resumes `ending.tscn`, which is the completed-game state.
Continue becomes "View ending" and keeps that state until New Game. Ending
presentation code is unchanged by this branch.

The ending thread should retain the defeat call if final defeat still means
campaign completion. If a playable escape becomes a required stage, add its
scene basename to `STAGES`, make it the final boss's `next_level`, and record
`ending.tscn` only when that stage completes. `enter_stage` writes an empty
checkpoint for a newly unlocked stage; `capture` only writes while the current
scene matches the saved stage, so returning to title during aftermath cannot
replace the earned next stage with the defeated boss.

Regression coverage is in `tests/campaign_save_check.gd`. It exercises real diya
and plank interactions, death retry, title Continue, side-room policy, malformed
and obsolete saves, snapshot isolation, boss completion, New Game reset, and a
fresh Godot child process reopening the river save. `menus_check.gd` also isolates
its New Game save from the player's file.
