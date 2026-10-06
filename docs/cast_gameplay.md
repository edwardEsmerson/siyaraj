# Cast assets in gameplay

Updated 2026-10-06. The preview shows the asset library; gameplay selects poses
from actual movement, attack and story events.

| Subject | Live use |
| --- | --- |
| Siya | Existing 15-animation movement, weapons, damage, diya and victory integration. |
| Basic rakshas and Brute | Walk/idle, anticipation/contact/recovery and defeat across the campaign, weapons playground and sandbox. |
| Ground shooter | Walk, charge, actual projectile release, recovery and defeat. Interrupted charges cannot show a release. |
| Winged forest demon | Flight, charge, projectile release pose, recovery and defeat. Its `dive` pose briefly accompanies firing; its existing ranged flight behavior is unchanged. |
| Khara | All ten states, with the separate gada following the 26 reviewed hand registrations. Ladi handling and defeat hide the weapon. |
| Swaminathan | Eleven full-body sprites for 10 through 0 heads, with attack origins, glows and the hurtbox aligned to the supplied art. |
| Robin | Expanded cast frames for flight, hover, hint, pointing, perched chatter and perching in the existing guide behavior. |
| Raj | Sulk, dramatic reaction and freed in the ending reached after Swaminathan. |

Art stays at 0.5 scale and mirrors around its registered anchor. Existing collision
shapes, damage, attack durations, projectile origins and boss transitions remain
unchanged. Melee contact frames coincide with the active damage window. Regular
enemies still disappear from gameplay immediately on defeat; an independent,
non-colliding sprite finishes their death animation and removes itself. Khara
retains his existing 1.4-second defeat sequence, using his drawn fall.

## Playtest

F5 opens the title. In the debug Playtest menu, use the enemy and Khara snapshots
to fight the animated cast, or select **Art / cast and animation preview** or
**Story / Raj rescued ending**. Campaign instances use the same enemy scenes,
so these changes also apply to all three levels and their showdowns.

`tests/cast_gameplay_check.gd` verifies actual melee damage windows, ranged
release/interruption, mirroring, harmless defeat cleanup, Khara's hand anchors
and weapon visibility, and Raj's rescue sequence. The full runner has 30 suites.
`tools/pack_check.gd` also verifies cast resources from an exported PCK, including
JSON metadata needed by Khara and the preview. Screenshots are under
`docs/screenshots/cast-gameplay/`.

## Assets still awaiting content or a design decision

- **Swaminathan review:** the previously missing `swaminathan-states` art arrived
  through the remaining head-state branch commits and is now integrated. The old
  cast-preview library still contains the earlier rejected design. Review the new
  state sheet and playtest the 80-HP fight as requested in `TODO.md`.
- **Dhoomketu:** his code-driven fight is playable, but no Dhoomketu sprite set
  is supplied in the cast library.
- **Robin combat poses:** peck, dive, sparks, hypnosis, dizzy and wake are
  reserved for the undecided Robin boss/story sequence. The current companion
  has no combat or hypnosis state to attach them to.
- **Audio:** playback is integrated (see `AUDIO_CATALOG.md`); public-release
  licensing remains a separate decision in `TODO.md`.
- **Comic panels, curtain illustrations and remaining props/effects:** the
  briefs are tasks for creating assets, not completed illustrations waiting to
  be wired into the game.

These cases remain explicit in `TODO.md`; preview availability alone does not
resolve their missing content or design decisions.
