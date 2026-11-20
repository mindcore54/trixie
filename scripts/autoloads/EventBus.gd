extends Node
## Central typed signal bus for decoupled gameplay, UI bust reactions, and game juice.

enum WitchEmotion {
	NORMAL,
	CONFIADA,
	NERVIOSA_SUDANDO,
	SONROJADA_PICANTE,
	HOLLIN_DERROTA,
	CUTIN_HABILIDAD,
}

var timers_paused: bool = false

# Action queue & movement
signal action_queued(station_id: StringName, queue_index: int, world_pos: Vector2)
signal action_queue_cleared()
signal action_step_completed(station_id: StringName, combo_pitch_step: int)

# Brewing & cauldron stability
signal cauldron_brew_started(cauldron_id: int, recipe_id: StringName)
signal cauldron_progress_updated(cauldron_id: int, brew_ratio: float, overheat_ratio: float)
signal cauldron_potion_ready(cauldron_id: int, recipe_id: StringName, is_hot_bonus: bool)
signal cauldron_exploded(cauldron_id: int, remaining_hearts: int)

# Witch reactive portrait & abilities
signal witch_emotion_changed(emotion: WitchEmotion, duration_sec: float)
signal witch_ability_triggered(witch_id: StringName, cutin_texture: Texture2D)

# Customers, queue & spicy dialogue
signal customer_arrived(customer_id: StringName, queue_slot: int, requested_recipe: StringName)
signal customer_served(customer_id: StringName, gold_earned: int, tip_multiplier: float, affinity_gained: int)
signal customer_patience_expired(customer_id: StringName, remaining_hearts: int)
signal customer_dialogue_requested(customer_id: StringName, portrait_texture: Texture2D, line_text: String, is_spicy: bool)
signal queue_overflow_triggered()

# Run economy & roguelite loop
signal gold_changed(new_total: int, delta: int)
signal xp_changed(level: int, current_xp: int, required_xp: int)
signal combo_changed(new_combo: int, multiplier: float)
signal day_started(day_number: int, duration_sec: float, is_boss_shift: bool)
signal day_ended(day_number: int)
signal upgrade_draft_requested(options: Array[Resource])
signal upgrade_selected(upgrade_id: StringName)
signal run_ended(victory: bool, reason: StringName, essence_earned: int)
