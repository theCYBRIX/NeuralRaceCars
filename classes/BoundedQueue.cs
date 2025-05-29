using Godot;
using System;
using System.Collections.Generic;

public partial class BoundedQueue<T> : GodotObject
{
	private readonly Queue<T> queue = new Queue<T>();
	private readonly int maxSize;

	public BoundedQueue(int maxSize)
	{
		this.maxSize = maxSize;
	}

	public void Enqueue(T item)
	{
		if (queue.Count == maxSize)
		{
			queue.Dequeue(); // Remove the oldest item
		}
		queue.Enqueue(item);
	}

	public T Dequeue()
	{
		return queue.Dequeue();
	}

	public int Count => queue.Count;

	public T[] ToArray()
	{
		return queue.ToArray();
	}

	public void Clear()
	{
		queue.Clear();
	}
}
