class_name CarSettings
extends Resource


@export var tire_friction : float = 10 : set = set_tire_friction
@export var deactivate_on_contact : bool = true : set = set_deactivate_on_contact


func set_tire_friction(friction : float) -> void:
	if tire_friction == friction:
		return
	
	tire_friction = friction
	emit_changed()


func set_deactivate_on_contact(enabled : bool) -> void:
	if deactivate_on_contact == enabled:
		return
	
	deactivate_on_contact = enabled
	emit_changed()
