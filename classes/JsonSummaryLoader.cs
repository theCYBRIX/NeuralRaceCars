using Godot;
using System;
using System.IO;
using System.Text;
using System.Text.Json;
using Dictionary = Godot.Collections.Dictionary;
using Array = Godot.Collections.Array;
using FileAccess = System.IO.FileAccess;

public partial class JsonSummaryLoader : Node
{
	public Dictionary GetJsonSummary(string path)
	{
		var summary = new Dictionary
		{
			["generation"] = 0,
			["highest_score"] = 0,
			["input_map"] = new Array(),
			["network_count"] = 0,
			["layout"] = new Dictionary(),
			["time_elapsed"] = 0
		};

		using var stream = new FileStream(ProjectSettings.GlobalizePath(path), FileMode.Open, FileAccess.Read);
		using var reader = new StreamReader(stream, Encoding.UTF8);
		var jsonBytes = Encoding.UTF8.GetBytes(reader.ReadToEnd());
		var jsonReader = new Utf8JsonReader(jsonBytes, new JsonReaderOptions { AllowTrailingCommas = true });

		bool layoutCaptured = false;
		int networksFound = 0;

		while (jsonReader.Read())
		{
			if (jsonReader.TokenType == JsonTokenType.PropertyName)
			{
				string propName = jsonReader.GetString();

				switch (propName)
				{
					case "generation":
						jsonReader.Read();
						summary["generation"] = jsonReader.GetInt32();
						break;

					case "highest_score":
						jsonReader.Read();
						summary["highest_score"] = (float)jsonReader.GetDouble();
						break;

					case "input_map":
						jsonReader.Read(); // StartArray
						var inputMap = new Array();
						while (jsonReader.Read() && jsonReader.TokenType != JsonTokenType.EndArray)
						{
							inputMap.Add(jsonReader.GetInt32());
						}
						summary["input_map"] = inputMap;
						break;

					case "time_elapsed":
						jsonReader.Read();
						summary["time_elapsed"] = (float)jsonReader.GetDouble();
						break;

					case "networks":
						jsonReader.Read(); // StartArray
						while (jsonReader.Read()){
							if (jsonReader.TokenType == JsonTokenType.EndArray){
								summary["network_count"] = networksFound;
								break;
							}
							if (layoutCaptured){
								jsonReader.Skip();
							} else {
								var layout = TryExtractLayout(ref jsonReader);
								if (layout != null)
								{
									summary["layout"] = layout;
									layoutCaptured = true;
								}
							}
							networksFound++;
						}
						break;
				}
			}
		}

		return summary;
	}

	private Dictionary TryExtractLayout(ref Utf8JsonReader reader)
	{
		Dictionary layout = null;
		int objectDepth = 0;

		while (reader.Read())
		{
			if (reader.TokenType == JsonTokenType.StartObject)
				objectDepth++;

			if (reader.TokenType == JsonTokenType.EndObject)
			{
				objectDepth--;
				if (objectDepth <= 0) break;
			}

			if (reader.TokenType == JsonTokenType.PropertyName)
			{
				string prop = reader.GetString();

				if (prop == "layout")
				{
					reader.Read(); // Advance to layout object
					layout = ParseLayout(ref reader);
				}
				else if (prop == "network")
				{
					layout = TryExtractLayout(ref reader); // Network is inside a wrapper class
				}
			}
		}

		return layout;
	}

	private Dictionary ParseLayout(ref Utf8JsonReader reader)
	{
		return ParseJsonObject(ref reader);
	}

	private Variant ParseJsonValue(ref Utf8JsonReader reader)
	{
		switch (reader.TokenType)
		{
			case JsonTokenType.StartObject:
				return ParseJsonObject(ref reader);
			case JsonTokenType.StartArray:
				return ParseJsonArray(ref reader);
			case JsonTokenType.String:
				return reader.GetString();
			case JsonTokenType.Number:
				if (reader.TryGetInt64(out long l))
					return (long)l;
				return (double)reader.GetDouble();
			case JsonTokenType.True:
				return true;
			case JsonTokenType.False:
				return false;
			case JsonTokenType.Null:
				return "null";
			default:
				throw new InvalidOperationException($"Unsupported JSON token: {reader.TokenType}");
		}
	}

	private Dictionary ParseJsonObject(ref Utf8JsonReader reader)
	{
		var dict = new Dictionary();

		if (reader.TokenType != JsonTokenType.StartObject)
			return dict;

		while (reader.Read())
		{
			if (reader.TokenType == JsonTokenType.EndObject)
				break;

			if (reader.TokenType == JsonTokenType.PropertyName)
			{
				string key = reader.GetString();
				reader.Read();
				var val = ParseJsonValue(ref reader);
				dict[key] = Variant.From(val);
			}
		}
		return dict;
	}

	private Array ParseJsonArray(ref Utf8JsonReader reader)
	{
		var array = new Array();

		while (reader.Read())
		{
			if (reader.TokenType == JsonTokenType.EndArray)
				break;

			array.Add(Variant.From(ParseJsonValue(ref reader)));
		}

		return array;
	}
}
