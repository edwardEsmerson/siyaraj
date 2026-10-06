# Submission checklist

PR #39 restores campaign music and effects. The silent-build validation below
is historical; rebuild and resolve the supplied soundtrack licensing before submission.

## Prepared locally

Game source revision: `2a30b612f2489e23a00cf22108c5589542fde721`, the final
HUD polish merge fetched from GitHub. All 32 regression checks passed on that
revision. The exported pack passed checks across 19 scenes, including required
credits and font notices and exclusion of local build storage and audio.

- Team name and five supplied names recorded; General Track confirmed by the team.
- Root credits and MIT project license added. Fonts retain their OFL notices.
- AI art and coding assistance disclosed with known provenance and remaining gaps.
- Audio was removed during submission preparation and restored by PR #39.
- Web release preset added with threads off and an `index.html` entry point.
- Itch.io page copy, controls, and hints prepared in `docs/itch_page.md`.

## Must be finished before calling the submission complete

- [ ] Verify all five members and the POC Discord username against Indieconnect; confirm the POC is in the event server and has the correct team role/thread.
- [ ] Confirm every AI code tool used by teammates and every retained asset's origin in CREDITS.md. Approve the MIT license for team contributions.
- [ ] Confirm the public repository is accessible while signed out. Push the prepared documentation, export configuration, and audio removals without rewriting history.
- [ ] Preserve the Hour 12 scope form and proposal, and compare the submitted game with that locked plan. `proposal.pdf` exists locally; submission of the official form has not been verified.
- [ ] Resolve the deadline discrepancy with the organisers. The pasted announcement says 6 October at 4pm, but the team reports that the freeze has not taken effect. This checkout contains commits after that time. Never backdate commits or uploads.
- [ ] Resolve redistribution licensing for the restored soundtrack, or replace it with licensed audio.
- [ ] Export and inspect the browser ZIP. Confirm the build report identifies the intended source revision and file hashes.
- [ ] Run the browser build and check New Game, the full campaign, deaths/retries, all bosses, the ending, controls, pause, fullscreen, and browser reload behavior.
- [ ] Have a first-time player finish the campaign. Record the real duration. The target is 10 to 15 minutes; first playthroughs over 20 minutes are not fully evaluated. No timing has been measured by release preparation.
- [ ] Create and publish the itch.io browser page. Copy the final credits in full, along with the prepared controls and hints.
- [ ] Replace README.md's missing itch.io link with the real public URL and push it before the applicable freeze.
- [ ] Confirm the itch.io URL plays while signed out and submit that URL via the official Discord bot. Keep its acknowledgement.

The team must verify development began at Hour 0 and that its design and
direction reflect its own work. Commit history provides evidence, but this
release preparation does not certify either condition. Previously committed
unlicensed audio remains in history; ask the organisers whether its removal
from the submitted source tree and browser build is sufficient.
