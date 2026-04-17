using System.Threading;
using FXRateDashboard.Services;
using FXRateDashboard.ViewModels;
using FXRateDashboard.Views;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Drawing = System.Drawing;
using Drawing2D = System.Drawing.Drawing2D;
using Forms = System.Windows.Forms;
using WpfApplication = System.Windows.Application;
using WpfExitEventArgs = System.Windows.ExitEventArgs;
using WpfStartupEventArgs = System.Windows.StartupEventArgs;
using System.Runtime.InteropServices;
using System.Net;
using System.Net.Http;
using System.Windows.Threading;

namespace FXRateDashboard;

public partial class App : WpfApplication
{
    private Mutex? _singleInstanceMutex;
    private IHost? _host;
    private Forms.NotifyIcon? _notifyIcon;
    private TrayMenuWindow? _trayMenuWindow;

    protected override async void OnStartup(WpfStartupEventArgs e)
    {
        base.OnStartup(e);

        _singleInstanceMutex = new Mutex(initiallyOwned: true, "FXRateDashboard.SingleInstance", out var createdNew);
        if (!createdNew)
        {
            Shutdown();
            return;
        }

        ShutdownMode = System.Windows.ShutdownMode.OnMainWindowClose;

        _host = Host.CreateDefaultBuilder()
            .ConfigureServices(services =>
            {
                services.AddSingleton<IUiDispatcher, WpfUiDispatcher>();
                services.AddSingleton<IAppPathProvider, AppPathProvider>();
                services.AddSingleton<ITokenProtector, TokenProtector>();
                services.AddSingleton<ISettingsStore, SettingsStore>();
                services.AddSingleton<ICacheStore, CacheStore>();
                services.AddSingleton<IRateQueryMapper, RateQueryMapper>();
                services.AddSingleton<IStartupLaunchService, StartupLaunchService>();
                services.AddHttpClient<IWiseRateClient, WiseRateClient>(client =>
                {
                    client.BaseAddress = new Uri("https://api.wise.com/");
                    client.Timeout = TimeSpan.FromSeconds(20);
                })
                .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
                {
                    // Wise requests should work even if a local system proxy like Clash was
                    // shut down but left behind in Windows proxy settings.
                    UseProxy = false,
                    AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate
                });

                services.AddSingleton<MainViewModel>();
                services.AddSingleton<MainWindow>();
                services.AddTransient<SettingsViewModel>();
                services.AddTransient<SettingsWindow>();
                services.AddSingleton<TrayMenuWindow>();
            })
            .Build();

        await _host.StartAsync();

        var mainWindow = _host.Services.GetRequiredService<MainWindow>();
        await mainWindow.PrepareForFirstShowAsync();
        MainWindow = mainWindow;
        mainWindow.Show();
        _ = Dispatcher.BeginInvoke(() => ShowWidget(mainWindow), DispatcherPriority.ApplicationIdle);

        InitializeTray(mainWindow);
    }

    protected override async void OnExit(WpfExitEventArgs e)
    {
        if (_notifyIcon is not null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }

        _trayMenuWindow?.Close();

        if (_host is not null)
        {
            await _host.StopAsync();
            _host.Dispose();
        }

        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }

    private void InitializeTray(MainWindow mainWindow)
    {
        _trayMenuWindow = _host!.Services.GetRequiredService<TrayMenuWindow>();
        _trayMenuWindow.ToggleVisibilityRequested += (_, _) => Dispatcher.Invoke(mainWindow.ToggleVisibilityFromMenu);
        _trayMenuWindow.ToggleModeRequested += async (_, _) => await Dispatcher.InvokeAsync(mainWindow.ToggleModeFromMenuAsync);
        _trayMenuWindow.ToggleClickThroughRequested += async (_, _) => await Dispatcher.InvokeAsync(mainWindow.ToggleClickThroughFromMenuAsync);
        _trayMenuWindow.SettingsRequested += (_, _) => Dispatcher.Invoke(mainWindow.OpenSettingsFromTray);
        _trayMenuWindow.QuitRequested += (_, _) => Dispatcher.Invoke(mainWindow.Close);

        _notifyIcon = new Forms.NotifyIcon
        {
            Visible = true,
            Text = "FX Rate Dashboard",
            Icon = CreateTrayIcon()
        };

        _notifyIcon.MouseUp += (_, eventArgs) =>
        {
            if (eventArgs.Button == Forms.MouseButtons.Right || eventArgs.Button == Forms.MouseButtons.Left)
            {
                Dispatcher.Invoke(() => _trayMenuWindow?.ToggleAtCursor());
            }
        };
    }

    private static Drawing.Icon CreateTrayIcon()
    {
        using var bitmap = new Drawing.Bitmap(16, 16);
        using var graphics = Drawing.Graphics.FromImage(bitmap);
        graphics.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias;
        graphics.Clear(Drawing.Color.Transparent);

        var bounds = new Drawing.Rectangle(1, 1, 14, 14);
        using var path = CreateRoundedRectanglePath(bounds, 4);
        using var fillBrush = new Drawing2D.LinearGradientBrush(
            bounds,
            Drawing.Color.FromArgb(159, 232, 112),
            Drawing.Color.FromArgb(93, 194, 82),
            90f);
        using var borderPen = new Drawing.Pen(Drawing.Color.FromArgb(22, 51, 0), 1f);
        graphics.FillPath(fillBrush, path);
        graphics.DrawPath(borderPen, path);

        using var linePen = new Drawing.Pen(Drawing.Color.White, 1.6f)
        {
            StartCap = Drawing2D.LineCap.Round,
            EndCap = Drawing2D.LineCap.Round,
            LineJoin = Drawing2D.LineJoin.Round
        };
        var points = new[]
        {
            new Drawing.PointF(4f, 10.8f),
            new Drawing.PointF(6.3f, 8.2f),
            new Drawing.PointF(8.1f, 9.1f),
            new Drawing.PointF(10.4f, 5.8f),
            new Drawing.PointF(12f, 7.2f)
        };
        graphics.DrawLines(linePen, points);

        var iconHandle = bitmap.GetHicon();
        try
        {
            return (Drawing.Icon)Drawing.Icon.FromHandle(iconHandle).Clone();
        }
        finally
        {
            DestroyIcon(iconHandle);
        }
    }

    private static Drawing2D.GraphicsPath CreateRoundedRectanglePath(Drawing.Rectangle bounds, int radius)
    {
        var diameter = radius * 2;
        var path = new Drawing2D.GraphicsPath();
        path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr hIcon);

    private static void ShowWidget(MainWindow mainWindow)
    {
        mainWindow.RestoreFromTray();

        var originalTopmost = mainWindow.Topmost;
        mainWindow.Topmost = true;
        mainWindow.Topmost = originalTopmost;
    }
}
