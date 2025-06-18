extends LinearTrack

signal car_entered_slow_zone(car : NeuralCar)
signal car_exited_slow_zone(car : NeuralCar)

func _on_slow_zone_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
	if body is NeuralCar:
		car_entered_slow_zone.emit(body)


func _on_slow_zone_body_shape_exited(_body_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
	if body is NeuralCar:
		car_exited_slow_zone.emit(body)
