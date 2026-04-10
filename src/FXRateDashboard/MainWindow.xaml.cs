using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using FXRateDashboard.ViewModels;
using FXRateDashboard.Views;
using Microsoft.Extensions.DependencyInjection;

namespace FXRateDashboard;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;
    private readonly IServiceProvider _serviceProvider;
    private bool _isInitialized;
    private bool _isSettingsDialogOpen;

    public MainWindow(MainViewModel viewModel, IServiceProvider serviceProvider)
    {
        InitializeComponent();
        _viewModel = viewModel;
        _serviceProvider = serviceProvider;
        DataContext = _viewModel;

        Loaded += MainWindow_OnLoaded;
        Closing += MainWindow_OnClosing;
        LocationChanged += MainWindow_OnLocationChanged;
        _viewModel.RequestOpenSettings += ViewModel_OnRequestOpenSettings;
    }

    public void OpenSettingsFromTray()
    {
        _ = ShowSettingsDialogAsync();
    }

    public async Task PrepareForFirstShowAsync()
    {
        await _viewModel.EnsureSettingsLoadedAsync();
        ApplyWindowPlacement();
    }

    private async void MainWindow_OnLoaded(object sender, RoutedEventArgs e)
    {
        if (_isInitialized)
        {
            return;
        }

        _isInitialized = true;
        await _viewModel.InitializeAsync();
    }

    private void MainWindow_OnLocationChanged(object? sender, EventArgs e)
    {
        if (!IsLoaded)
        {
            return;
        }

        _viewModel.UpdateWindowPosition(Left, Top);
    }

    private async void MainWindow_OnClosing(object? sender, CancelEventArgs e)
    {
        _viewModel.RequestOpenSettings -= ViewModel_OnRequestOpenSettings;
        await _viewModel.ShutdownAsync(Left, Top);
    }

    private void ViewModel_OnRequestOpenSettings(object? sender, EventArgs e)
    {
        OpenSettingsFromTray();
    }

    private async Task ShowSettingsDialogAsync()
    {
        if (_isSettingsDialogOpen)
        {
            return;
        }

        _isSettingsDialogOpen = true;
        try
        {
            Activate();

            var dialog = _serviceProvider.GetRequiredService<SettingsWindow>();
            dialog.Load(_viewModel.CreateEditableSettings());
            dialog.PositionNearOwner(this);
            dialog.SubmitSettingsAsync = _viewModel.ApplySettingsAsync;

            dialog.ShowDialog();
            if (dialog.CreatedSettings is null)
            {
                return;
            }
        }
        finally
        {
            _isSettingsDialogOpen = false;
        }
    }

    private void ApplyWindowPlacement()
    {
        var placement = _viewModel.GetSavedWindowPlacement();
        var width = Width;
        var height = Height;

        if (placement.Left.HasValue && placement.Top.HasValue)
        {
            Left = placement.Left.Value;
            Top = placement.Top.Value;
        }
        else
        {
            Left = SystemParameters.WorkArea.Right - width - 24;
            Top = SystemParameters.WorkArea.Top + 24;
        }

        var minLeft = SystemParameters.VirtualScreenLeft;
        var minTop = SystemParameters.VirtualScreenTop;
        var maxLeft = SystemParameters.VirtualScreenLeft + SystemParameters.VirtualScreenWidth - width;
        var maxTop = SystemParameters.VirtualScreenTop + SystemParameters.VirtualScreenHeight - height;

        Left = Math.Max(minLeft, Math.Min(Left, maxLeft));
        Top = Math.Max(minTop, Math.Min(Top, maxTop));
    }

    private void DragSurface_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || _viewModel.IsPositionLocked)
        {
            return;
        }

        DragMove();
    }
}
