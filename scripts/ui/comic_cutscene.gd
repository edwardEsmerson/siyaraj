extends CanvasLayer
## Reusable full-screen comic sequence and in-world dialogue card.

signal cutscene_started
signal panel_changed(index: int, count: int)
signal finished

const ADVANCE_ACTION: StringName = &"ui_accept"

@onready var backdrop: ColorRect = $Backdrop
@onready var panel_art: TextureRect = $PanelArt
@onready var featured_art: TextureRect = $FeaturedArt
@onready var bubble: PanelContainer = $DialogueBubble
@onready var portrait: TextureRect = $DialogueBubble/Contents/Portrait
@onready var speaker_label: Label = $DialogueBubble/Contents/Words/Speaker
@onready var dialogue_label: Label = $DialogueBubble/Contents/Words/Dialogue
@onready var advance_label: Label = $DialogueBubble/Contents/Words/Advance
@onready var bubble_tail: Polygon2D = $BubbleTail
@onready var bubble_tail_inner: Polygon2D = $BubbleTailInner

var _panels: Array[Dictionary] = []
var _index: int = 0
var _hint_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


## Each entry has `text`, optional `speaker`, `portrait`, and `texture` resource paths.
func play(panels: Array[Dictionary]) -> void:
	_panels.clear()
	for entry in panels:
		if not entry.has("text"):
			push_warning("ComicCutscene: skipped a panel without dialogue text")
			continue
		_panels.append(entry.duplicate())
	if _panels.is_empty():
		stop()
		finished.emit()
		return
	_index = 0
	_hint_mode = false
	backdrop.show()
	panel_art.show()
	show()
	cutscene_started.emit()
	_show_current_panel()


## Show a portrait dialogue card over the current level; ui_accept dismisses it.
func show_hint(speaker: String, text: String, portrait_texture: Texture2D = null) -> void:
	_panels = [{"speaker": speaker, "text": text, "portrait": portrait_texture}]
	_index = 0
	_hint_mode = true
	backdrop.hide()
	panel_art.hide()
	show()
	_show_current_panel()


func stop() -> void:
	_panels.clear()
	_hint_mode = false
	hide()


func _show_current_panel() -> void:
	if _index < 0 or _index >= _panels.size():
		return
	var panel: Dictionary = _panels[_index]
	panel_art.texture = _load_texture(panel.get("texture"))
	panel_art.visible = not _hint_mode and panel_art.texture != null
	featured_art.texture = _load_texture(panel.get("subject"))
	featured_art.visible = not _hint_mode and featured_art.texture != null
	speaker_label.text = str(panel.get("speaker", ""))
	speaker_label.visible = not speaker_label.text.is_empty()
	dialogue_label.text = str(panel.get("text", ""))
	portrait.texture = _load_texture(panel.get("portrait"))
	portrait.visible = portrait.texture != null
	advance_label.text = "Enter / A: dismiss" if _hint_mode else "Enter / A: continue"
	bubble.show()
	bubble_tail.show()
	bubble_tail_inner.show()
	panel_changed.emit(_index, _panels.size())


func _load_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	if value is String or value is StringName:
		return load(str(value)) as Texture2D
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not visible or get_tree().paused or event.is_echo() or not event.is_action_pressed(ADVANCE_ACTION):
		return
	get_viewport().set_input_as_handled()
	if _hint_mode:
		stop()
		finished.emit()
		return
	_index += 1
	if _index >= _panels.size():
		stop()
		finished.emit()
		return
	_show_current_panel()
