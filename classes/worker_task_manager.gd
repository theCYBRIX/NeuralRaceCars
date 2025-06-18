class_name WorkerTaskManager
extends RefCounted


var _worker_thread_tasks : Array[int] = []
var _worker_thread_group_tasks : Array[int] = []
var _worker_task_array_mutex := Mutex.new()
var _worker_group_task_array_mutex := Mutex.new()
var _wait_for_tasks_mutex := Mutex.new()
var _wait_for_group_tasks_mutex := Mutex.new()


func add_task(task : Callable) -> int:
	var task_id := WorkerThreadPool.add_task(task)
	_worker_task_array_mutex.lock()
	_worker_thread_tasks.append(task_id)
	_worker_task_array_mutex.unlock()
	return task_id


func add_group_task(task : Callable, elements : int, tasks_needed : int = -1, high_priority := false, description := "") -> int:
	var task_id := WorkerThreadPool.add_group_task(task, elements, tasks_needed, high_priority, description)
	_worker_group_task_array_mutex.lock()
	_worker_thread_group_tasks.append(task_id)
	_worker_group_task_array_mutex.unlock()
	return task_id


func wait_for_tasks() -> void:
	_wait_for_tasks_mutex.lock()
	var more_tasks_available := true
	while more_tasks_available:
		_worker_task_array_mutex.lock()
		var tasks := _worker_thread_tasks
		_worker_thread_tasks = []
		_worker_task_array_mutex.unlock()
		for task in tasks:
			WorkerThreadPool.wait_for_task_completion(task)
		_worker_task_array_mutex.lock()
		more_tasks_available = _worker_thread_tasks.size() > 0
		_worker_task_array_mutex.unlock()
	_wait_for_tasks_mutex.unlock()


func wait_for_group_tasks() -> void:
	_wait_for_group_tasks_mutex.lock()
	var more_tasks_available := true
	while more_tasks_available:
		_worker_group_task_array_mutex.lock()
		var tasks := _worker_thread_group_tasks
		_worker_thread_group_tasks = []
		_worker_group_task_array_mutex.unlock()
		for task in tasks:
			WorkerThreadPool.wait_for_group_task_completion(task)
		_worker_group_task_array_mutex.lock()
		more_tasks_available = _worker_thread_group_tasks.size() > 0
		_worker_group_task_array_mutex.unlock()
	_wait_for_group_tasks_mutex.unlock()


func wait_for_all_tasks() -> void:
	wait_for_tasks()
	wait_for_group_tasks()


func is_empty() -> bool:
	return _worker_thread_tasks.is_empty() and _worker_thread_group_tasks.is_empty()


func is_tasks_empty() -> bool:
	return _worker_thread_tasks.is_empty()


func is_group_tasks_empty() -> bool:
	return _worker_thread_group_tasks.is_empty()


func get_total_num_tasks() -> int:
	return _worker_thread_tasks.size() + _worker_thread_group_tasks.size()


func get_num_worker_tasks() -> int:
	return _worker_thread_tasks.size()


func get_num_worker_group_tasks() -> int:
	return _worker_thread_group_tasks.size()
