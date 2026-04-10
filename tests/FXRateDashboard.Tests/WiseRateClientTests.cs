using System.Net;
using System.Net.Http;
using System.Text;
using FXRateDashboard.Services;

namespace FXRateDashboard.Tests;

public sealed class WiseRateClientTests
{
    [Fact]
    public async Task GetCurrentRateAsync_ParsesWiseTimestampWithoutColonInOffset()
    {
        var handler = new StubHttpMessageHandler(
            """
            [{"rate":7.2451,"source":"USD","target":"CNY","time":"2026-04-10T09:52:31+0000"}]
            """);
        var client = new WiseRateClient(new HttpClient(handler)
        {
            BaseAddress = new Uri("https://api.wise.com/")
        });

        var point = await client.GetCurrentRateAsync("USD", "CNY", "token");

        Assert.Equal(7.2451m, point.Rate);
        Assert.Equal(new DateTimeOffset(2026, 4, 10, 9, 52, 31, TimeSpan.Zero), point.TimestampUtc);
    }

    private sealed class StubHttpMessageHandler : HttpMessageHandler
    {
        private readonly string _payload;

        public StubHttpMessageHandler(string payload)
        {
            _payload = payload;
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(_payload, Encoding.UTF8, "application/json")
            };

            return Task.FromResult(response);
        }
    }
}
