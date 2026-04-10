using System.Net;

namespace FXRateDashboard.Services;

public sealed class WiseApiException : Exception
{
    public WiseApiException(string message, HttpStatusCode? statusCode = null)
        : base(message)
    {
        StatusCode = statusCode;
    }

    public HttpStatusCode? StatusCode { get; }
}
