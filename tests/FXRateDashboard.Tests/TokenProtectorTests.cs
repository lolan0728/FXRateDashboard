using FXRateDashboard.Services;

namespace FXRateDashboard.Tests;

public sealed class TokenProtectorTests
{
    [Fact]
    public void ProtectAndUnprotect_RoundTripsText()
    {
        var protector = new TokenProtector();
        const string token = "wise-test-token";

        var cipher = protector.Protect(token);
        var plain = protector.Unprotect(cipher);

        Assert.NotEqual(token, cipher);
        Assert.Equal(token, plain);
    }
}
