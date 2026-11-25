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
var settings_modal: SettingsModal
var arpg_quest_hud: ArpgQuestHud
var npc_dialogue_modal: NpcDialogueModal

var _opened_upgrade_from_pause: bool = false
var _opened_settings_from_pause: bool = false
var _was_mouse_captured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_apply_mobile_graphics_profile()

	arpg_quest_hud = ArpgQuestHud.new()
	arpg_quest_hud.name = "ArpgQuestHud"
	$UILayer.add_child(arpg_quest_hud)
	$UILayer.move_child(arpg_quest_hud, hud_ui.get_index() + 1)
	arpg_quest_hud.set_arpg_visible(GameState.is_arpg_mode())

	npc_dialogue_modal = NpcDialogueModal.new()
	npc_dialogue_modal.name = "NpcDialogueModal"
	$UILayer.add_child(npc_dialogue_modal)

	settings_modal = SettingsModal.new()
	settings_modal.name = "SettingsModal"
	$UILayer.add_child(settings_modal)

	# BattleManager -> UI
	battle_manager.hud_updated.connect(_on_hud_updated)
	battle_manager.popup_requested.connect(floating_popups.spawn_popup)
	battle_manager.attack_swung.connect(hud_ui.trigger_crosshair_bloom)
	battle_manager.hit_landed.connect(hud_ui.trigger_crosshair_hit)
	battle_manager.chant_started.connect(func(skill_type: String, word: Dictionary, max_time: float) -> void:
		_unlock_mouse()
		get_tree().paused = true
		chant_overlay.open_chant(skill_type, word, max_time)
	)
	battle_manager.wave_cleared.connect(func() -> void:
		_unlock_mouse()
		get_tree().paused = true
		blessing_modal.open_blessings()
	)
	battle_manager.battle_ended.connect(func(is_victory: bool, reached_wave: int) -> void:
		_unlock_mouse()
		get_tree().paused = true
		result_modal.open_result(is_victory, reached_wave)
	)

	# ARPG Adventure Mode -> Quest HUD & NPC Dialogue / Japanese Quiz Modal
	arpg_quest_hud.interact_pressed.connect(battle_manager.interact_with_nearest_npc)
	battle_manager.arpg_hud_state_changed.connect(func(
		zone_name: String, quest_title: String, quest_desc: String,
		compass_text: String, quiz_done: int, quiz_total: int,
		near_npc_name: String, near_npc_hint: String
	) -> void:
		arpg_quest_hud.set_arpg_visible(GameState.is_arpg_mode())
		arpg_quest_hud.update_quest(zone_name, quest_title, quest_desc, compass_text, quiz_done, quiz_total)
		arpg_quest_hud.set_interact_prompt(not near_npc_name.is_empty(), near_npc_name, near_npc_hint)
	)
	battle_manager.arpg_npc_interact_requested.connect(func(npc_data: Dictionary, already_cleared: bool) -> void:
		_unlock_mouse()
		get_tree().paused = true
		npc_dialogue_modal.open_npc(npc_data, already_cleared)
	)
	battle_manager.arpg_cutscene_requested.connect(func(cutscene_id: String, cdata: Dictionary) -> void:
		_unlock_mouse()
		GameState.battle["paused"] = true
		get_tree().paused = true
		npc_dialogue_modal.open_cutscene(
			cutscene_id,
			String(cdata.get("title", "")),
			String(cdata.get("speaker", "")),
			String(cdata.get("icon", "🌸")),
			String(cdata.get("jp_tts", "")),
			cdata.get("lines", [])
		)
	)
	npc_dialogue_modal.quiz_completed.connect(func(npc_id: String, reward: Dictionary, first_clear: bool) -> void:
		battle_manager.on_arpg_quiz_reward_claimed(npc_id, reward, first_clear)
		_on_hud_updated()
	)
	npc_dialogue_modal.dialogue_closed.connect(func(npc_id: String) -> void:
		get_tree().paused = false
		battle_manager.on_arpg_npc_dialogue_closed(npc_id)
		_lock_mouse()
		_on_hud_updated()
	)
	npc_dialogue_modal.cutscene_closed.connect(func(cutscene_id: String) -> void:
		if cutscene_id == "ch1_epilogue":
			GameState.battle["paused"] = true
			get_tree().paused = true
			result_modal.open_result(true, 1)
			return
		GameState.battle["paused"] = false
		get_tree().paused = false
		_lock_mouse()
		_on_hud_updated()
	)

	# HUD -> BattleManager / Modals
	hud_ui.attack_pressed.connect(battle_manager.perform_attack_a)
	hud_ui.jump_pressed.connect(battle_manager.perform_jump)
	hud_ui.dash_pressed.connect(battle_manager.perform_dash)
	hud_ui.sig_skill_pressed.connect(func() -> void: battle_manager.initiate_skill_chant("sig"))
	hud_ui.ult_skill_pressed.connect(func() -> void: battle_manager.initiate_skill_chant("ult"))
	hud_ui.joystick_changed.connect(func(vec: Vector2) -> void: battle_manager.joy_vector = vec)
	hud_ui.upgrade_requested.connect(func(tab: String) -> void:
		_opened_upgrade_from_pause = false
		_unlock_mouse()
		get_tree().paused = true
		upgrade_modal.open_modal(tab)
	)
	hud_ui.settings_requested.connect(func() -> void:
		_opened_settings_from_pause = false
		_unlock_mouse()
		GameState.battle["paused"] = true
		get_tree().paused = true
		settings_modal.open_settings()
	)
	hud_ui.pause_requested.connect(_open_pause_menu)

	# ChantOverlay -> BattleManager
	chant_overlay.chant_completed.connect(func(is_success: bool, is_typed_perfect: bool) -> void:
		get_tree().paused = false
		battle_manager.complete_skill_chant(is_success, is_typed_perfect)
		_lock_mouse()
	)
	chant_overlay.chant_cancelled.connect(func() -> void:
		get_tree().paused = false
		battle_manager.cancel_chant()
		_lock_mouse()
	)

	# UpgradeModal -> Resume or return to PauseModal
	upgrade_modal.modal_closed.connect(func() -> void:
		if _opened_upgrade_from_pause:
			_opened_upgrade_from_pause = false
			pause_modal.open_pause()
		elif not chant_overlay.visible and not blessing_modal.visible and not result_modal.visible and not settings_modal.visible and not npc_dialogue_modal.visible:
			GameState.battle["paused"] = false
			get_tree().paused = false
			_lock_mouse()
		_on_hud_updated()
	)

	# SettingsModal -> Resume or return to PauseModal
	settings_modal.modal_closed.connect(func() -> void:
		if _opened_settings_from_pause:
			_opened_settings_from_pause = false
			pause_modal.open_pause()
		elif not chant_overlay.visible and not blessing_modal.visible and not result_modal.visible and not upgrade_modal.visible and not npc_dialogue_modal.visible:
			GameState.battle["paused"] = false
			get_tree().paused = false
			_lock_mouse()
		_on_hud_updated()
	)

	# BlessingModal -> Apply blessing and start next wave
	blessing_modal.blessing_selected.connect(func(bid: String) -> void:
		GameState.apply_blessing(bid)
		GameState.battle["paused"] = false
		get_tree().paused = false
		battle_manager.start_wave(int(GameState.battle["wave"]) + 1)
		_lock_mouse()
	)

	# PauseModal actions
	pause_modal.resume_pressed.connect(_resume_from_pause)
	pause_modal.upgrade_pressed.connect(func() -> void:
		_opened_upgrade_from_pause = true
		_unlock_mouse()
		upgrade_modal.open_modal("skills")
	)
	pause_modal.dictionary_pressed.connect(func() -> void:
		_opened_upgrade_from_pause = true
		_unlock_mouse()
		upgrade_modal.open_modal("dict")
	)
	pause_modal.settings_pressed.connect(func() -> void:
		_opened_settings_from_pause = true
		_unlock_mouse()
		settings_modal.open_settings()
	)
	pause_modal.restart_pressed.connect(_restart_battle)
	pause_modal.return_to_menu_pressed.connect(_return_to_main_menu)

	# ResultModal actions
	result_modal.replay_pressed.connect(_restart_battle)
	result_modal.return_to_menu_pressed.connect(_return_to_main_menu)

	GameState.state_changed.connect(_on_hud_updated)

	# Immediately start the 3D battle with the Main Menu selections!
	call_deferred("_begin_battle")


func _apply_mobile_graphics_profile() -> void:
	if not UiStyle.is_mobile_device():
		return
	# Cut 3D HiDPI pixel fill-rate by ~2.6x while keeping 2D UI razor-sharp!
	get_viewport().scaling_3d_scale = 0.62
	var dir_light := get_node_or_null("World3D/DirectionalLight3D") as DirectionalLight3D
	if dir_light != null:
		dir_light.shadow_enabled = false
		dir_light.light_energy = 1.28
	var fill_light := get_node_or_null("World3D/FillLight3D") as DirectionalLight3D
	if fill_light != null:
		fill_light.visible = false
	var center_light := get_node_or_null("World3D/CenterLight") as OmniLight3D
	if center_light != null:
		center_light.visible = false


func _exit_tree() -> void:
	_unlock_mouse()


func _has_any_modal_open() -> bool:
	return (
		chant_overlay.visible
		or upgrade_modal.visible
		or blessing_modal.visible
		or pause_modal.visible
		or result_modal.visible
		or (settings_modal != null and settings_modal.visible)
		or (npc_dialogue_modal != null and npc_dialogue_modal.visible)
	)


func _lock_mouse() -> void:
	if hud_ui != null and hud_ui.is_mobile_mode():
		return
	if _has_any_modal_open() or get_tree().paused or not GameState.battle["active"]:
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unlock_mouse() -> void:
	_was_mouse_captured = false
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _begin_battle() -> void:
	battle_manager.start_new_battle()
	_lock_mouse()
	_on_hud_updated()


func _process(_delta: float) -> void:
	if hud_ui == null:
		return
	var in_combat: bool = bool(GameState.battle["active"]) and (not bool(GameState.battle["paused"])) and (not _has_any_modal_open())
	var locked: bool = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	# In Web browsers, pressing ESC exits Pointer Lock natively without emitting KEY_ESCAPE.
	# Detect that CAPTURED -> VISIBLE transition during active combat and open Pause UI immediately!
	if in_combat and (not hud_ui.is_mobile_mode()) and _was_mouse_captured and (not locked):
		_was_mouse_captured = false
		_open_pause_menu()
		hud_ui.set_mouse_lock_ui(false, false, false)
		return

	_was_mouse_captured = locked and in_combat
	hud_ui.set_mouse_lock_ui(locked, in_combat, false)


func _unhandled_input(event: InputEvent) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	# Desktop: clicking on the 3D battlefield locks the mouse cursor for free-look + crosshair combat
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if not hud_ui.is_mobile_mode() and not _has_any_modal_open() and not get_tree().paused and bool(GameState.battle["active"]):
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					_lock_mouse()
					get_viewport().set_input_as_handled()
					return

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == KEY_ESCAPE or ke.keycode == KEY_P):
			if npc_dialogue_modal != null and npc_dialogue_modal.visible:
				return
			if settings_modal != null and settings_modal.visible:
				settings_modal.close_modal()
				get_viewport().set_input_as_handled()
			elif pause_modal.visible:
				pause_modal.visible = false
				_resume_from_pause()
				get_viewport().set_input_as_handled()
			elif not chant_overlay.visible and not upgrade_modal.visible and not blessing_modal.visible and not result_modal.visible:
				# ESC or P ALWAYS opens the Pause UI directly (and unlocks the mouse!)
				_open_pause_menu()
				get_viewport().set_input_as_handled()


func _open_pause_menu() -> void:
	if chant_overlay.visible or blessing_modal.visible or result_modal.visible or (npc_dialogue_modal != null and npc_dialogue_modal.visible):
		return
	_unlock_mouse()
	GameState.battle["paused"] = true
	get_tree().paused = true
	pause_modal.open_pause()


func _resume_from_pause() -> void:
	GameState.battle["paused"] = false
	get_tree().paused = false
	_lock_mouse()
	_on_hud_updated()


func _restart_battle() -> void:
	get_tree().paused = false
	battle_manager.start_new_battle()
	_lock_mouse()
	_on_hud_updated()


func _return_to_main_menu() -> void:
	_unlock_mouse()
	get_tree().paused = false
	GameState.reset_battle_state()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_hud_updated() -> void:
	hud_ui.refresh(battle_manager.enemies.size(), battle_manager.get_active_boss())
