@tool
extends Control


@export var text : String = "" : set = set_text, get = get_text
@export var label_details : LabelDetails = LabelDetails.NONE : set = set_label_details
@export var num_decimal_digits : int = 2 : set = set_num_decimal_digits


@export_category("Range")
@export var value : float = 0 : set = set_value, get = get_value
@export var min_value : float = 0 : set = set_min_value
@export var max_value : float = 100 : set = set_max_value


@onready var margin_container: MarginContainer = $MarginContainer
@onready var label: Label = $MarginContainer/VBoxContainer/Label
@onready var h_slider: HSlider = $MarginContainer/VBoxContainer/HSlider


var _slider_dragging := false


enum LabelDetails {
	NONE,
	PERCENT,
	VALUE
}


func _ready() -> void:
	h_slider.min_value = min_value
	h_slider.max_value = max_value
	h_slider.value = value
	
	_update_label_text()


func set_text(str : String) -> void:
	text = str
	_update_label_text()


func set_value(num : float) -> void:
	value = num
	if h_slider and not _slider_dragging:
		h_slider.value = value
	_update_label_text()


func get_text() -> String:
	return text


func get_value() -> float:
	return value


func get_percent() -> float:
	return (value - min_value) / float(max_value - min_value)


func set_min_value(num : float) -> void:
	min_value = minf(num, max_value)
	if h_slider:
		h_slider.min_value = min_value


func set_max_value(num : float) -> void:
	max_value = maxf(num, min_value)
	if h_slider:
		h_slider.max_value = max_value


func set_label_details(details : LabelDetails) -> void:
	label_details = details
	_update_label_text()


func set_num_decimal_digits(digits : int) -> void:
	num_decimal_digits = max(digits, 0)
	_update_label_text()


func _update_label_text() -> void:
	if not label:
		return
	
	var updated_text := text
	var append_colon := false
	
	if label_details != LabelDetails.NONE and updated_text.ends_with(":"):
		append_colon = true
		updated_text = updated_text.trim_suffix(":")
	
	match label_details:
		LabelDetails.VALUE:
			updated_text += _value_string() if text.is_empty() else " (%s)" % _value_string()
		LabelDetails.PERCENT:
			updated_text += _percentage_string() if text.is_empty() else " (%s)" % _percentage_string()
		_:
			label.text = updated_text
			return
	
	if append_colon:
		updated_text += ":"
	
	label.text = updated_text


func _percentage_string() -> String:
	return ("%." + str(num_decimal_digits) + "f%%") % get_percent()


func _value_string() -> String:
	return str(value)


func _get_minimum_size() -> Vector2:
	if margin_container:
		return margin_container.get_minimum_size()
	else:
		return Vector2.ZERO


func _on_h_slider_value_changed(new_value: float) -> void:
	value = new_value


func _on_h_slider_drag_started() -> void:
	_slider_dragging = true


func _on_h_slider_drag_ended(_value_changed: bool) -> void:
	_slider_dragging = false
