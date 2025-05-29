using Godot;
using Godot.Collections;
using System;
using System.Buffers.Binary;
using System.IO;
using System.Net.Sockets;

public partial class BinaryIoHandler : Node
{
	[Export]
	public string HostAddress { get; set; }

	[Export(PropertyHint.Range, "0,65535")]
	public int HostPort { get; set; }

	[Export]
	public bool Enabled { get; set; } = true;

	[Export]
	public bool Autostart { get; set; } = false;

	private TcpClient _client;
	private NetworkStream _stream;
	private BinaryWriter _writer;
	private BinaryReader _reader;

	private BoundedQueue<float> _responseTimes = new BoundedQueue<float>(100);
	private StopWatch _timer = new StopWatch();

	private const int PROCESS_INPUTS_ENDPOINT = 2;

	public override void _Ready()
	{
		SetProcess(false);
		if (!Engine.IsEditorHint() && Autostart)
		{
			Start();
		}
	}

	public bool Connect(string host, int port)
	{
		try
		{
			_client = new TcpClient(host, port);
			_client.NoDelay = true; // disable Nagle's algorithm
			_stream = _client.GetStream();
			_writer = new BinaryWriter(_stream);
			_reader = new BinaryReader(_stream);
			return true;
		}
		catch (Exception e)
		{
			GD.PushError($"Connection error: {e.Message}");
			return false;
		}
	}

	public void Disconnect()
	{
		_reader?.Close();
		_writer?.Close();
		_stream?.Close();
		_client?.Close();
	}

	public bool IsConnected()
	{
		return _client != null && _client.Connected;
	}
	
	public void Start(){
		Connect(HostAddress, HostPort);
	}

	public void Test(object array)
	{
		GD.Print("Okay, that works");
	}

	public Dictionary<string, Godot.Collections.Array<double>> ProcessInputs(Dictionary<int, Godot.Collections.Array<double>> inputs)
	{
		_timer.Start();

		var outputs = new Dictionary<string, Godot.Collections.Array<double>>();

		using var ms = new MemoryStream();
		using var bufferWriter = new BinaryWriter(ms);

		// Write request header
		bufferWriter.Write(System.Net.IPAddress.HostToNetworkOrder(PROCESS_INPUTS_ENDPOINT));
		bufferWriter.Write(System.Net.IPAddress.HostToNetworkOrder(inputs.Count));

		foreach (var kvp in inputs)
		{
			int netId = System.Net.IPAddress.HostToNetworkOrder(kvp.Key);
			int count = System.Net.IPAddress.HostToNetworkOrder(kvp.Value.Count);
			bufferWriter.Write(netId);
			bufferWriter.Write(count);

			foreach (double val in kvp.Value)
			{
				Span<byte> span = stackalloc byte[8];
				BinaryPrimitives.WriteDoubleBigEndian(span, val);
				bufferWriter.Write(span);
			}
		}

		// Send full request in one write
		_writer.Write(ms.ToArray());
		_writer.Flush();

		// Read and handle response
		int errorCode = System.Net.IPAddress.NetworkToHostOrder(_reader.ReadInt32());
		if (errorCode != 0)
		{
			GD.PushError($"Binary IO Channel returned error code: {errorCode}");
			return outputs;
		}

		int numNetworks = System.Net.IPAddress.NetworkToHostOrder(_reader.ReadInt32());
		if (numNetworks != inputs.Count)
		{
			GD.PushError($"Num networks changed {numNetworks} -> {inputs.Count}");
		}

		for (int i = 0; i < numNetworks; i++)
		{
			int networkId = System.Net.IPAddress.NetworkToHostOrder(_reader.ReadInt32());
			int numOutputs = System.Net.IPAddress.NetworkToHostOrder(_reader.ReadInt32());
			Godot.Collections.Array<double> outputArray = new Godot.Collections.Array<double>(new double[numOutputs]);

			for (int j = 0; j < numOutputs; j++)
			{
				byte[] buffer = _reader.ReadBytes(8);
				if (BitConverter.IsLittleEndian)
					System.Array.Reverse(buffer);
				outputArray[j] = BitConverter.ToDouble(buffer, 0);
			}

			outputs[networkId.ToString()] = outputArray;
		}

		_timer.Stop();
		_responseTimes.Enqueue(_timer.GetDuration());

		return outputs;
	}

	public float GetAverageResponseTime()
	{
		if (_responseTimes.Count == 0)
			return 0f;

		float sum = 0f;
		foreach (float time in _responseTimes.ToArray())
		{
			sum += time;
		}

		return sum / _responseTimes.Count;
	}
}
