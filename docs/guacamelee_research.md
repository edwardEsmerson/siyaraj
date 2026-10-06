# Guacamelee reference review

## Scope and evidence

This pass inspected loaded gameplay frames from LazyGamingDogs' complete
[Guacamelee STCE longplay](https://www.youtube.com/watch?v=4fd22E-dd28),
the map-linked [Tule Tree chest walkthrough](https://www.youtube.com/watch?v=SKDuf1uXgzY),
and actual Forest del Chivo and Tule Tree map images. It sampled the longplay;
it did not watch every minute or examine every room in every region.
Frames still buffering after a seek were excluded from the observations.
Timestamp labels below use the loaded video time, rounded to seconds.

| Recording | Time | Observed layout | Design use |
| --- | --- | --- | --- |
| STCE longplay | 16:40 | House interior with separate door thresholds | Make the hollow entrance a distinct destination |
| STCE longplay | 19:33 | Enclosed encounter with raised central and side platforms | Reserve broad floors and ledges for future encounters |
| STCE longplay | 21:48 | Rising forest passage beneath a sloping ceiling | Treat overhead clearance as part of traversal |
| STCE longplay | 24:03 | Town rooftops connected by staggered ledges | Use the setting's surfaces to establish a climb |
| STCE longplay | 26:37 | Separate combo training interior | Give an entered room a focused purpose |
| STCE longplay | 1:09:53 | Town routes rise between buildings; an upper exit has a direction sign | Mark optional entrances where the route changes elevation |
| STCE longplay | 1:40:02 | Enclosed combat room with a sloped, layered floor | Separate encounter ground from demanding jump takeoffs |
| STCE longplay | 1:59:54 | Boss arena with a long horizontal platform | Leave space to tune future boss movement |
| STCE longplay | 2:24:55 | Open woodland platforms beside a large trunk and a door | Enter the nest through the banyan climb |
| STCE longplay | 2:28:26 | Confined stone passage between vertical hazards | Future hazard rooms can change the rhythm of traversal |
| STCE longplay | 2:30:03 | Wide enclosed arena after the narrow passage | Alternate concentrated movement with encounter space |
| STCE longplay | 3:39:56 | Narrow stone obstacles above a water hazard | Future river geometry can make falls distinct from forest pits |
| Tule Tree chest walkthrough | 0:40 | Outdoor descent returns to a broad lower floor | Root chamber changes from descent to ascent |
| Tule Tree chest walkthrough | 1:25 | Compact enclosed maze ends at a heart reward | Side rooms need an explicit completion point |
| Tule Tree chest walkthrough | 1:50 | A raised reward sits inside a bounded platform layout | Nest ends on a distinct upper landing |
| Tule Tree chest walkthrough | 2:20 | Save point before overhead hazards and an opening | Put a local diya before the outer branch crossings |

## Map study

The [Tule Tree map](https://images.akamai.steamusercontent.com/ugc/597029787396268167/8D6A5C75548AAAB1AD2AD328D3F7C46122C5BD48/)
shows a tall central route. Door links lead sideways into bounded rooms at
several elevations. Some rooms have two linked thresholds, and save points
sit at junctions. This suggests a climb with distinct detours rather than a
single uninterrupted staircase. Chest numbers on this image belong to the
reference game, not Siyaraj.

The [Forest del Chivo map screenshot](https://content.instructables.com/FMI/HLI0/JL2KIK46/FMIHLI0JL2KIK46.jpg)
shows only part of the region. It includes a horizontal trail, a descending
shaft, elevated passages, ability barriers, and a door beside a shop. It is
evidence for branching layout, not a complete atlas of the forest.

The [treasure guide](https://steamcommunity.com/sharedfiles/filedetails/?id=214940561)
links the Tule Tree walkthrough and describes rewards reached through side
doors and small traversal puzzles. Its older edition differs from STCE in
some treasure and area connections. The [written walkthrough](https://gamefaqs.gamespot.com/pc/834694-guacamelee-super-turbo-championship-edition/faqs/67841)
was used to check forest progression and dungeon loops. Footage and map
observations above remain separate from walkthrough-derived information.

## Adaptation in Siyaraj

The forest now has two optional transported sections. A door on the root
ridge enters a descending chamber with a steep ascent to the return door.
A door on the banyan's top branch enters the trunk climb and canopy nest.
The nest has a mid-climb diya, a crown rest with another diya, and an outer
branch dash chain ending at an encounter landing. Reaching the far door and
pressing E completes either section and returns to its forest entrance.

Both rooms use current jump/dash physics and grey editable scene geometry.
They do not reproduce Guacamelee's wall jumps, dimension swapping, uppercut,
chicken tunnels, or ability gates. Future enemies can occupy the designated
root bed, crown, and nest markers. Difficulty and enjoyment still need a
continuous human playtest; isolated reachability checks cannot establish them.
