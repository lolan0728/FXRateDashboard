using System.Security.Cryptography;
using System.Text;

namespace FXRateDashboard.Services;

public sealed class TokenProtector : ITokenProtector
{
    public string Protect(string plainText)
    {
        if (string.IsNullOrWhiteSpace(plainText))
        {
            return string.Empty;
        }

        var plainBytes = Encoding.UTF8.GetBytes(plainText.Trim());
        var protectedBytes = ProtectedData.Protect(plainBytes, optionalEntropy: null, scope: DataProtectionScope.CurrentUser);
        return Convert.ToBase64String(protectedBytes);
    }

    public string? Unprotect(string? cipherText)
    {
        if (string.IsNullOrWhiteSpace(cipherText))
        {
            return null;
        }

        try
        {
            var cipherBytes = Convert.FromBase64String(cipherText);
            var plainBytes = ProtectedData.Unprotect(cipherBytes, optionalEntropy: null, scope: DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(plainBytes);
        }
        catch (FormatException)
        {
            return null;
        }
        catch (CryptographicException)
        {
            return null;
        }
    }
}
