class_name FileType
extends Node

const TYPE_JSON := "json"
const TYPE_RES := "res"
const TYPE_TRES := "tres"

static func get_type_description(type : String):
	match type:
		TYPE_JSON:
			return "JavaScript Object Notation"
		TYPE_RES:
			return "Resource File"
		TYPE_TRES:
			return "Text Resource File"
		_:
			return ""
