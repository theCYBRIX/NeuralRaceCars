class_name CustomMainLoop
extends MainLoop

const FIXED_DELTA := 1.0 / 60

func _initialize():
	print("Initialized:")
	print("  Running at a fixed interval of: %s seconds" % str(FIXED_DELTA))

func _process(delta):
	# Return true to end the main loop.
	return Input.get_mouse_button_mask() != 0 || Input.is_key_pressed(KEY_ESCAPE)

func _finalize():
	print("Finalized:")
