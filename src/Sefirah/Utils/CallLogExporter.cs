using System.Globalization;
using System.Text;
using Sefirah.Data.Models;

namespace Sefirah.Utils;

/// <summary>
/// Writes the call history to Documents\Sefirah\call-log.json and call-log.csv so outside
/// automations (e.g. a GitHub stats job) can count connected / not connected calls.
/// Files are replaced atomically; the export never touches the app database.
/// </summary>
public static class CallLogExporter
{
    public static string ExportFolder { get; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Sefirah");

    private static readonly SemaphoreSlim Gate = new(1, 1);

    public static async Task ExportAsync(string deviceName, IReadOnlyList<CallLog> logs)
    {
        await Gate.WaitAsync().ConfigureAwait(false);
        try
        {
            Directory.CreateDirectory(ExportFolder);
            var rows = logs
                .OrderByDescending(l => l.TimestampMillis)
                .Select(l => new CallLogExportRow(
                    l.CallLogId,
                    l.LocalTimestamp.ToString("yyyy-MM-dd'T'HH:mm:sszzz", CultureInfo.InvariantCulture),
                    l.IsOutgoing ? "outgoing" : "incoming",
                    l.CallType.ToString(),
                    ToSnake(l.Outcome),
                    l.IsConnected,
                    l.DurationSeconds,
                    PhoneNumberUtils.CleanDialInput(l.CallContact.Address),
                    l.CallContact.DisplayName))
                .ToList();

            var export = new CallLogExport(
                DateTimeOffset.Now.ToString("yyyy-MM-dd'T'HH:mm:sszzz", CultureInfo.InvariantCulture),
                deviceName,
                rows.Count,
                rows.Count(r => r.Connected),
                rows.Count(r => !r.Connected),
                rows);

            var json = JsonSerializer.Serialize(export, JsonOptions);
            await WriteAtomicAsync(Path.Combine(ExportFolder, "call-log.json"), json).ConfigureAwait(false);
            await WriteAtomicAsync(Path.Combine(ExportFolder, "call-log.csv"), ToCsv(rows)).ConfigureAwait(false);
        }
        finally
        {
            Gate.Release();
        }
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        TypeInfoResolver = new System.Text.Json.Serialization.Metadata.DefaultJsonTypeInfoResolver()
    };

    private static string ToSnake(CallOutcome outcome) => outcome switch
    {
        CallOutcome.NotConnected => "not_connected",
        _ => outcome.ToString().ToLowerInvariant()
    };

    private static string ToCsv(List<CallLogExportRow> rows)
    {
        var sb = new StringBuilder();
        sb.AppendLine("call_log_id,timestamp,direction,call_type,outcome,connected,duration_seconds,number,contact_name");
        foreach (var r in rows)
        {
            sb.Append(r.CallLogId).Append(',')
              .Append(r.Timestamp).Append(',')
              .Append(r.Direction).Append(',')
              .Append(r.CallType).Append(',')
              .Append(r.Outcome).Append(',')
              .Append(r.Connected ? "true" : "false").Append(',')
              .Append(r.DurationSeconds).Append(',')
              .Append(Csv(r.Number)).Append(',')
              .Append(Csv(r.ContactName)).AppendLine();
        }
        return sb.ToString();
    }

    private static string Csv(string? value)
    {
        value ??= string.Empty;
        return value.IndexOfAny([',', '"', '\n', '\r']) >= 0 ? $"\"{value.Replace("\"", "\"\"")}\"" : value;
    }

    private static async Task WriteAtomicAsync(string path, string content)
    {
        var temp = path + ".tmp";
        await File.WriteAllTextAsync(temp, content, new UTF8Encoding(true)).ConfigureAwait(false);
        File.Move(temp, path, overwrite: true);
    }

    private sealed record CallLogExport(
        string ExportedAt,
        string Device,
        int TotalCalls,
        int ConnectedCalls,
        int NotConnectedCalls,
        List<CallLogExportRow> Calls);

    private sealed record CallLogExportRow(
        long CallLogId,
        string Timestamp,
        string Direction,
        string CallType,
        string Outcome,
        bool Connected,
        long DurationSeconds,
        string Number,
        string? ContactName);
}
