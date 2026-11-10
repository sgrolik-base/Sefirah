using Microsoft.UI.Xaml.Media;
using Sefirah.Data.Models;
using Windows.UI;

namespace Sefirah.Helpers;

/// <summary>Colors for call-log status icons (used from x:Bind on the UI thread).</summary>
public static class CallStatusHelper
{
    private static readonly Dictionary<CallOutcome, SolidColorBrush> Brushes = [];

    public static SolidColorBrush StatusBrush(CallOutcome outcome)
    {
        if (Brushes.TryGetValue(outcome, out var brush))
            return brush;

        var color = outcome switch
        {
            CallOutcome.Connected => Color.FromArgb(255, 0x3F, 0xB9, 0x50),    // green
            CallOutcome.Voicemail => Color.FromArgb(255, 0xD2, 0x99, 0x22),    // amber
            CallOutcome.Blocked or CallOutcome.Unknown => Color.FromArgb(255, 0x8B, 0x8B, 0x8B), // gray
            _ => Color.FromArgb(255, 0xE5, 0x53, 0x4B)                         // red: not connected, missed, rejected
        };

        brush = new SolidColorBrush(color);
        Brushes[outcome] = brush;
        return brush;
    }
}
