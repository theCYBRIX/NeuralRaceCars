class_name FileFilter
extends RefCounted

var file_extension : String
var description : String

func _init(extension : String, readable_name : String = "") -> void:
	self.file_extension = extension
	self.description = readable_name


static func get_file_filters(types : Array[String]) -> Array[FileFilter]:
	var filters : Array[FileFilter] = []
	filters.resize(types.size())
	for i in range(types.size()):
		filters[i] = get_file_filter(types[i])
	return filters


static func get_file_filter(type : String, readable_name := "") -> FileFilter:
	if readable_name == "":
		readable_name = FileType.get_type_description(type)
	return FileFilter.new(type, readable_name)
