using System.Globalization;

namespace FXRateDashboard.Utilities;

public static class CurrencyCodeCatalog
{
    private static readonly Lazy<HashSet<string>> KnownCodes = new(BuildKnownCodes);

    public static bool IsKnownCode(string? code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            return false;
        }

        return KnownCodes.Value.Contains(code.Trim().ToUpperInvariant());
    }

    private static HashSet<string> BuildKnownCodes()
    {
        var codes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var culture in CultureInfo.GetCultures(CultureTypes.SpecificCultures))
        {
            try
            {
                var symbol = new RegionInfo(culture.Name).ISOCurrencySymbol;
                if (!string.IsNullOrWhiteSpace(symbol))
                {
                    codes.Add(symbol.Trim().ToUpperInvariant());
                }
            }
            catch (ArgumentException)
            {
                // Skip cultures without region metadata.
            }
        }

        foreach (var extraCode in new[]
                 {
                     "AED", "AFN", "ALL", "AMD", "AOA", "ARS", "AUD", "AZN", "BAM", "BDT",
                     "BGN", "BHD", "BIF", "BMD", "BND", "BOB", "BRL", "BSD", "BWP", "BYN",
                     "BZD", "CAD", "CHF", "CLP", "CNY", "COP", "CRC", "CZK", "DJF", "DKK",
                     "DOP", "DZD", "EGP", "ERN", "ETB", "EUR", "FJD", "GBP", "GEL", "GHS",
                     "GMD", "GNF", "GTQ", "HKD", "HNL", "HRK", "HUF", "IDR", "ILS", "INR",
                     "IQD", "ISK", "JMD", "JOD", "JPY", "KES", "KHR", "KMF", "KRW", "KWD",
                     "KZT", "LAK", "LBP", "LKR", "MAD", "MDL", "MGA", "MKD", "MMK", "MNT",
                     "MOP", "MUR", "MXN", "MYR", "MZN", "NAD", "NGN", "NIO", "NOK", "NPR",
                     "NZD", "OMR", "PAB", "PEN", "PGK", "PHP", "PKR", "PLN", "PYG", "QAR",
                     "RON", "RSD", "RUB", "RWF", "SAR", "SCR", "SEK", "SGD", "SLE", "SOS",
                     "THB", "TND", "TOP", "TRY", "TTD", "TWD", "TZS", "UAH", "UGX", "USD",
                     "UYU", "UZS", "VND", "VUV", "WST", "XAF", "XCD", "XOF", "XPF", "YER",
                     "ZAR", "ZMW"
                 })
        {
            codes.Add(extraCode);
        }

        return codes;
    }
}
