extends Node3D
## Game Body scene coordinator: runs the 3D battle world, HUD, Chant, Blessings,
## Upgrades, Pause Menu, and Battle Result flow.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"

@onready var battle_manager: BattleManager = $World3D/BattleManager
@onready var floating_popups: FloatingPopupLayer = $UILayer/FloatingPopupLayer
@onready var hud_ui: HudUI = $UILayer/HudUI
@onready var chant_overlay: ChantOverlay = $UILayer/ChantOverlay
@onready var upgrade_modal: UpgradeModal = $UILayer/UpgradeModal
@onready var blessing_modal: BlessingModal = $UILayer/BlessingModal
@onready var pause_modal: PauseModal = $UILayer/PauseModal
@onready var result_modal: ResultModal = $UILayer/ResultModal

var _opened_upgrade_from_pause: bool = false


func _ready() -> void:
	get_tree().paused = false

	# BattleManager -> UI
	battle_manager.hud_updated.connect(_on_hud_updated)
	battle_manager.popup_requested.connect(floating_popups.spawn_popup)
	battle_manager.chant_started.connect(func(skill_type: String, word: Dictionary, max_time: float) -> void:
		get_tree().paused = true
		chant_overlay.open_chant(skill_type, word, max_time)
	)
	battle_manager.wave_cleared.connect(func() -> void:
		get_tree().paused = true
		blessing_modal.open_blessings()
	)
	battle_manager.battle_ended.connect(func(is_victory: bool, reached_wave: int) -> void:
		get_tree().paused = true
		result_modal.open_result(is_victory, reached_wave)
	)

	# HUD -> BattleManager / Modals
	hud_ui.attack_pressed.connect(battle_manager.perform_attack_a)
	hud_ui.dash_pressed.connect(battle_manager.perform_dash)
	hud_ui.sig_skill_pressed.connect(func() -> void: battle_manager.initiate_skill_chant("sig"))
	hud_ui.ult_skill_pressed.connect(func() -> void: battle_manager.initiate_skill_chant("ult"))
	hud_ui.joystick_changed.connect(func(vec: Vector2) -> void: battle_manager.joy_vector = vec)
	hud_ui.upgrade_requested.connect(func(tab: String) -> void:
		_opened_upgrade_from_pause = false
		get_tree().paused = true
		upgrade_modal.open_modal(tab)
	)
	hud_ui.pause_requested.connect(_open_pause_menu)

	# ChantOverlay -> BattleManager
	chant_overlay.chant_completed.connect(func(is_success: bool, is_typed_perfect: bool) -> void:
		get_tree().paused = false
		battle_manager.complete_skill_chant(is_success, is_typed_perfect)
	)
	chant_overlay.chant_cancelled.connect(func() -> void:
		get_tree().paused = false
		battle_manager.cancel_chant()
	)

	# UpgradeModal -> Resume or return to PauseModal
	upgrade_modal.modal_closed.connect(func() -> void:
		if _opened_upgrade_from_pause:
			_opened_upgrade_from_pause = false
			pause_modal.open_pause()
		elif not chant_overlay.visible and not blessing_modal.visible and not result_modal.visible:
			GameState.battle["paused"] = false
			get_tree().paused = false
		_on_hud_updated()
	)

	# BlessingModal -> Apply blessing and start next wave
	blessing_modal.blessing_selected.connect(func(bid: String) -> void:
		GameState.apply_blessing(bid)
		GameState.battle["paused"] = false
		get_tree().paused = false
		battle_manager.start_wave(int(GameState.battle["wave"]) + 1)
	)

	# PauseModal actions
	pause_modal.resume_pressed.connect(_resume_from_pause)
	pause_modal.upgrade_pressed.connect(func() -> void:
		_opened_upgrade_from_pause = true
		upgrade_modal.open_modal("skills")
	)
	pause_modal.restart_pressed.connect(_restart_battle)
	pause_modal.return_to_menu_pressed.connect(_return_to_main_menu)

	# ResultModal actions
	result_modal.replay_pressed.connect(_restart_battle)
	result_modal.return_to_menu_pressed.connect(_return_to_main_menu)

	GameState.state_changed.connect(_on_hud_updated)

	# Immediately start the 3D battle with the Main Menu selections!
	call_deferred("_begin_battle")


func _begin_battle() -> void:
	battle_manager.start_new_battle()
	_on_hud_updated()


func _unhandled_input(event: InputEvent) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == KEY_ESCAPE or ke.keycode == KEY_P):
			if pause_modal.visible:
				pause_modal.visible = false
				_resume_from_pause()
				get_viewport().set_input_as_handled()
			elif not chant_overlay.visible and not upgrade_modal.visible and not blessing_modal.visible and not result_modal.visible:
				_open_pause_menu()
				get_viewport().set_input_as_handled()


func _open_pause_menu() -> void:
	if chant_overlay.visible or blessing_modal.visible or result_modal.visible:
		return
	GameState.battle["paused"] = true
	get_tree().paused = true
	pause_modal.open_pause()


func _resume_from_pause() -> void:
	GameState.battle["paused"] = false
	get_tree().paused = false
	_on_hud_updated()


func _restart_battle() -> void:
	get_tree().paused = false
	battle_manager.start_new_battle()
	_on_hud_updated()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	GameState.reset_battle_state()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_hud_updated() -> void:
	hud_ui.refresh(battle_manager.enemies.size(), battle_manager.get_active_boss())
