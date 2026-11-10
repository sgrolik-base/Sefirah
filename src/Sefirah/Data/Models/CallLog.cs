namespace Sefirah.Data.Models;

public partial class CallLog(Contact callContact) : ObservableObject
{
    public Contact CallContact { get; } = callContact;

    public long CallLogId { get; set; }

    public long TimestampMillis { get; set; }

    public long DurationSeconds { get; set; }

    public CallLogType CallType { get; set; }

    private bool isSelected;
    public bool IsSelected
    {
        get => isSelected;
        set => SetProperty(ref isSelected, value);
    }

    public DateTimeOffset LocalTimestamp => DateTimeOffset.FromUnixTimeMilliseconds(TimestampMillis).ToLocalTime();

    public string FormattedDate => LocalTimestamp.ToString("d");

    public string FormattedTime => LocalTimestamp.ToString("h:mm tt");

    public string FormattedWhen => $"{FormattedDate} at {FormattedTime}";

    public string FormattedDuration
    {
        get
        {
            if (DurationSeconds <= 0)
            {
                return string.Empty;
            }

            var ts = TimeSpan.FromSeconds(DurationSeconds);
            if (ts.TotalHours >= 1)
            {
                return $"{(int)ts.TotalHours}h {ts.Minutes}m {ts.Seconds}s";
            }

            if (ts.TotalMinutes >= 1)
            {
                return $"{ts.Minutes}m {ts.Seconds}s";
            }

            return $"{ts.Seconds}s";
        }
    }

    public string CallTypeAndDuration => Outcome switch
    {
        CallOutcome.Connected => $"{CallType} · {FormattedDuration}",
        CallOutcome.NotConnected => $"{CallType} · not connected",
        _ => $"{CallType}"
    };

    public bool IsOutgoing => CallType is CallLogType.Outgoing;

    /// <summary>A call counts as connected when it was answered and lasted more than 0 seconds.</summary>
    public bool IsConnected => Outcome is CallOutcome.Connected;

    public CallOutcome Outcome => CallType switch
    {
        CallLogType.Incoming or CallLogType.Outgoing or CallLogType.AnsweredExternally
            => DurationSeconds > 0 ? CallOutcome.Connected : CallOutcome.NotConnected,
        CallLogType.Missed => CallOutcome.Missed,
        CallLogType.Rejected => CallOutcome.Rejected,
        CallLogType.Blocked => CallOutcome.Blocked,
        CallLogType.Voicemail => CallOutcome.Voicemail,
        _ => CallOutcome.Unknown
    };

    /// <summary>↗ outgoing, ↙ incoming/missed/rejected.</summary>
    public string DirectionArrow => IsOutgoing ? "↗" : "↙";
}

public enum CallOutcome
{
    Connected,
    NotConnected,
    Missed,
    Rejected,
    Blocked,
    Voicemail,
    Unknown
}
