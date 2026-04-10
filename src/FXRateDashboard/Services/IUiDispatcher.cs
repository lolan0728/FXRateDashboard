namespace FXRateDashboard.Services;

public interface IUiDispatcher
{
    Task InvokeAsync(Action action);
}
