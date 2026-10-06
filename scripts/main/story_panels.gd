extends RefCounted
## Dialogue adapted from siyaraj.refined.txt. Transcript asides are omitted.

const VILLAGE: String = "res://assets/backgrounds/title_skyline.png"
const FOREST: String = "res://assets/world/forest/diyalit/far.png"
const RIVER: String = "res://assets/world/river/titlematch/far.png"
const PALACE: String = "res://assets/world/palace/diyalit/arena.png"
const SIYA: String = "res://assets/sprites/siya/talk/01.png"
const RAJ: String = "res://assets/sprites/raj/dramatic/01.png"
const ROBIN: String = "res://assets/sprites/robin/hint/01.png"
const KHARA: String = "res://assets/sprites/khara/intro_roar/02.png"
const SWAMINATHAN: String = "res://assets/sprites/swaminathan-head/faces/01.png"


static func panel(background: String, speaker: String, text: String, subject: String = SIYA,
		supporting_subject: String = "") -> Dictionary:
	return {"texture": background, "speaker": speaker, "text": text,
		"subject": subject, "supporting_subject": supporting_subject}


static func opening() -> Array[Dictionary]:
	return [
		panel(VILLAGE, "Narrator", "Diwali evening. Siya helps her parents, the village firework makers, prepare the last boxes of rockets and sparklers."),
		panel(VILLAGE, "Mother", "Careful with those fuses, Siya. Has Raj brought the lanterns back yet?"),
		panel(VILLAGE, "Neighbour", "Have you seen Raj? He went towards the old gate, but he never came back."),
		panel(VILLAGE, "Siya", "He promised to watch the fireworks with me. I'll find him."),
		panel(VILLAGE, "Raj", "Siya! Stay back! Swaminathan has soldiers everywhere!", RAJ),
		panel(VILLAGE, "Swaminathan", "Your family taught this village to defy me. Raj comes with me to Lanka. Let us see how brave you are without him.", SWAMINATHAN, RAJ),
		panel(VILLAGE, "Narrator", "Siya reaches the gate just as Swaminathan carries Raj away. His guards disappear into the forest."),
		panel(FOREST, "Robin", "I saw where they went. Through Khara's forest, across Dhoomketu's ghats, then up to the palace. Follow me!", ROBIN),
		panel(FOREST, "Siya", "Then we go together. Raj, hold on. I'm coming.", SIYA, ROBIN),
	]


static func introduction(boss: String) -> Array[Dictionary]:
	match boss:
		"forest":
			return [
				panel(FOREST, "Khara", "Swaminathan ordered me to stop you. I would have done it gladly. You and Raj tore down my toll gate and let the villagers through for free.", KHARA),
				panel(FOREST, "Siya", "You were stealing their festival supplies. I'd tear it down again."),
				panel(FOREST, "Khara", "They laughed at me that night. Now you pay for both of you.", KHARA),
				panel(FOREST, "Robin", "Watch his raised gada. Dash behind the slam, then strike while he recovers.", ROBIN),
				panel(FOREST, "Siya", "I'm leaving this forest with a path to Raj. Stand aside."),
			]
		"river":
			return [
				panel(RIVER, "Dhoomketu", "So Khara failed. Swaminathan's prisoner stays in Lanka, and you stay on this bank."),
				panel(RIVER, "Dhoomketu", "Your parents exposed my stolen fireworks. You and Raj returned my barge to the village. They cheered while my name went up in smoke."),
				panel(RIVER, "Siya", "Those fireworks belonged to the families you robbed. Raj helped me give them back."),
				panel(RIVER, "Dhoomketu", "Then let your family's own craft burn your way home!"),
				panel(RIVER, "Robin", "His rockets warn before they launch. Find a safe lane, then strike while he reloads.", ROBIN),
			]
		"palace":
			return [
				panel(PALACE, "Raj", "Siya! Up here! The cage is locked. Don't let him corner you!", RAJ),
				panel(PALACE, "Swaminathan", "Your parents refused to make weapons for me. You and Raj lit the village square when I ordered darkness. Every cheer was an insult.", SWAMINATHAN),
				panel(PALACE, "Siya", "You kidnapped Raj because we wouldn't obey you? Open his cage."),
				panel(PALACE, "Swaminathan", "Khara and Dhoomketu could not settle their grudges. I will settle mine myself. Ten heads stand between you and Raj.", SWAMINATHAN),
				panel(PALACE, "Robin", "Watch the glowing heads. Find the safe lanes, then strike when he is spent.", ROBIN),
				panel(PALACE, "Siya", "Then I'll bring down every one of them."),
			]
	return []


static func aftermath(boss: String) -> Array[Dictionary]:
	match boss:
		"forest":
			return [
				panel(FOREST, "Narrator", "Khara falls. Beyond his broken gate, the forest path slopes down towards the river."),
				panel(FOREST, "Siya", "One of Swaminathan's guards down. Where did they take Raj next?"),
				panel(RIVER, "Robin", "Across the ghats. Dhoomketu controls the crossing. We must reach his barge before we can climb to Lanka.", ROBIN),
				panel(RIVER, "Siya", "Then we cross. Raj is counting on me."),
			]
		"river":
			return [
				panel(RIVER, "Narrator", "Dhoomketu's stolen barge falls silent. Across the water, the palace lamps mark the road to Lanka."),
				panel(RIVER, "Siya", "The crossing is open. Your stolen fireworks won't hurt anyone else."),
				panel(PALACE, "Robin", "The palace gate is ahead. Swaminathan keeps Raj in the throne hall.", ROBIN),
				panel(PALACE, "Siya", "You know this place well, Robin."),
				panel(PALACE, "Robin", "I know the way. Keep moving. We're almost there.", ROBIN),
			]
		"palace":
			return [
				panel(PALACE, "Narrator", "Swaminathan's last head falls. The lock on Raj's cage breaks."),
				panel(PALACE, "Swaminathan", "Robin... you brought her here, just as I ordered. How did you let this happen?", SWAMINATHAN),
				panel(PALACE, "Siya", "Ordered? Robin, what is he talking about?", SIYA, ROBIN),
				panel(PALACE, "Robin", "I have always served Swaminathan. I was sent to guide you into his guards, then into this hall. I thought you would never make it out.", ROBIN),
				panel(PALACE, "Siya", "You watched me risk everything for Raj. Every time you said we were together, you were leading me into a trap."),
				panel(PALACE, "Robin", "Yes. The directions were true. The friendship was a lie.", ROBIN),
				panel(PALACE, "Narrator", "Robin flies out through the palace window. Siya lets him go and runs to the open cage."),
				panel(PALACE, "Raj", "Siya! You came all this way for me.", RAJ, SIYA),
				panel(PALACE, "Siya", "Of course I did. You're safe now. We're going home.", SIYA, "res://assets/sprites/raj/freed/01.png"),
				panel(VILLAGE, "Narrator", "Back home, Siya's parents light the fireworks. Siya and Raj watch them together, just as they promised.", "res://assets/sprites/siya/victory/01.png", "res://assets/sprites/raj/freed/01.png"),
			]
	return []
