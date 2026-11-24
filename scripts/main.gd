extends Node3D
## Root scene coordinator connecting BattleManager with all UI overlays.

@onready var battle_manager: BattleManager = $BattleManager
@onready var floating_popups: FloatingPopupLayer = $UILayer/FloatingPopupLayer
@onready var hud_ui: HudUI = $UILayer/HudUI
@onready var chant_overlay: ChantOverlay = $UILayer/ChantOverlay
@onready var lobby_modal: LobbyModal = $UILayer/LobbyModal
@onready var upgrade_modal: UpgradeModal = $UILayer/UpgradeModal
@onready var blessing_modal: BlessingModal = $UILayer/BlessingModal


func _ready() -> void:
	# BattleManager -> UI
	battle_manager.hud_updated.connect(_on_hud_updated)
	battle_manager.popup_requested.connect(floating_popups.spawn_popup)
	battle_manager.chant_started.connect(chant_overlay.open_chant)
	battle_manager.wave_cleared.connect(blessing_modal.open_blessings)
	battle_manager.lobby_requested.connect(lobby_modal.open_lobby)

	# HUD -> BattleManager / Modals
	hud_ui.attack_pressed.connect(battle_manager.perform_attack_a)
	hud_ui.dash_pressed.connect(battle_manager.perform_dash)
	hud_ui.sig_skill_pressed.connect(func() -> void: battle_manager.initiate_skill_chant("sig"))
	hud_ui.ult_skill_pressed.connect(func() -> void: battle_manager.initiate_skill_chant("ult"))
	hud_ui.joystick_changed.connect(func(vec: Vector2) -> void: battle_manager.joy_vector = vec)
	hud_ui.upgrade_requested.connect(upgrade_modal.open_modal)
	hud_ui.lobby_requested.connect(lobby_modal.open_lobby)

	# ChantOverlay -> BattleManager
	chant_overlay.chant_completed.connect(battle_manager.complete_skill_chant)
	chant_overlay.chant_cancelled.connect(battle_manager.cancel_chant)

	# LobbyModal -> BattleManager
	lobby_modal.start_battle_pressed.connect(battle_manager.start_new_battle)

	# UpgradeModal -> Resume if lobby is closed
	upgrade_modal.modal_closed.connect(func() -> void:
		if not lobby_modal.visible and not chant_overlay.visible and not blessing_modal.visible:
			GameState.battle["paused"] = false
		_on_hud_updated()
	)

	# BlessingModal -> Apply blessing and start next wave
	blessing_modal.blessing_selected.connect(func(bid: String) -> void:
		GameState.apply_blessing(bid)
		GameState.battle["paused"] = false
		battle_manager.start_wave(int(GameState.battle["wave"]) + 1)
	)

	GameState.state_changed.connect(_on_hud_updated)
	_on_hud_updated()


func _on_hud_updated() -> void:
	hud_ui.refresh(battle_manager.enemies.size(), battle_manager.get_active_boss())
