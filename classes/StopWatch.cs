using Godot;
using System;
using System.Diagnostics;

public partial class StopWatch : GodotObject
{
	private Stopwatch stopwatch;
	private float durationMs;

	public StopWatch()
	{
		stopwatch = new Stopwatch();
		durationMs = 0f;
	}

	// Start the stopwatch
	public void Start()
	{
		durationMs = 0f;
		stopwatch.Restart();
	}

	// Stop the stopwatch and calculate the duration in milliseconds
	public void Stop()
	{
		stopwatch.Stop();
		durationMs = stopwatch.ElapsedTicks * (1000f / Stopwatch.Frequency);
	}

	// Get the duration in milliseconds (as a float)
	public float GetDuration()
	{
		return durationMs;
	}
}
