namespace FXRateDashboard.Services;

public interface ITokenProtector
{
    string Protect(string plainText);

    string? Unprotect(string? cipherText);
}
