using System.Windows;
using System.Windows.Threading;
using WpfApplication = System.Windows.Application;

namespace FXRateDashboard.Services;

public sealed class WpfUiDispatcher : IUiDispatcher
{
    public Task InvokeAsync(Action action)
    {
        var dispatcher = WpfApplication.Current?.Dispatcher ?? Dispatcher.CurrentDispatcher;
        return dispatcher.InvokeAsync(action).Task;
    }
}
