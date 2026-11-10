namespace Sefirah.Utils;

/// <summary>A tel: or sms: link opened from Windows. It only prefills UI, never calls or sends.</summary>
public sealed record ExternalLink(bool IsSms, IReadOnlyList<string> Numbers, string? Body);

public static class ExternalLinkParser
{
    /// <summary>
    /// Parses "tel:+420 739 017 476" or "sms:+420739017476,+421...?body=Ahoj%20%C5%A0t%C4%9Bp%C3%A1ne".
    /// Returns null for other schemes or links without anything usable.
    /// </summary>
    public static ExternalLink? Parse(string? rawUri)
    {
        if (string.IsNullOrWhiteSpace(rawUri))
            return null;

        var colon = rawUri.IndexOf(':');
        if (colon <= 0)
            return null;

        var scheme = rawUri[..colon].Trim();
        var rest = rawUri[(colon + 1)..].TrimStart('/');
        var isTel = scheme.Equals("tel", StringComparison.OrdinalIgnoreCase);
        var isSms = scheme.Equals("sms", StringComparison.OrdinalIgnoreCase)
            || scheme.Equals("smsto", StringComparison.OrdinalIgnoreCase);
        if (!isTel && !isSms)
            return null;

        var queryStart = rest.IndexOf('?');
        var addressPart = queryStart >= 0 ? rest[..queryStart] : rest;
        var query = queryStart >= 0 ? rest[(queryStart + 1)..] : string.Empty;

        // Parameters after ';' (ext=, phone-context=) are not dialable digits.
        var paramStart = addressPart.IndexOf(';');
        if (paramStart >= 0)
            addressPart = addressPart[..paramStart];

        var numbers = addressPart
            .Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(a => PhoneNumberUtils.CleanDialInput(Unescape(a)))
            .Where(n => n.Length > 0)
            .Distinct()
            .ToList();

        if (isTel)
            return numbers.Count > 0 ? new ExternalLink(false, [numbers[0]], null) : null;

        string? body = null;
        foreach (var pair in query.Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var eq = pair.IndexOf('=');
            var key = eq >= 0 ? pair[..eq] : pair;
            if (key.Equals("body", StringComparison.OrdinalIgnoreCase))
                body = eq >= 0 ? Unescape(pair[(eq + 1)..]) : string.Empty;
        }

        return numbers.Count > 0 || !string.IsNullOrEmpty(body)
            ? new ExternalLink(true, numbers, body)
            : null;
    }

    // '+' stays '+' (RFC 3986), only %XX is decoded.
    private static string Unescape(string value)
    {
        try
        {
            return Uri.UnescapeDataString(value);
        }
        catch (UriFormatException)
        {
            return value;
        }
    }
}
