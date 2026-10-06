extends Control

const Story = preload("res://scripts/main/story_panels.gd")


func _ready() -> void:
	$ComicCutscene.finished.connect(func() -> void:
		PlaytestNavigation.start_level("res://scenes/main/forest.tscn")
	)
	$ComicCutscene.play(Story.opening())
