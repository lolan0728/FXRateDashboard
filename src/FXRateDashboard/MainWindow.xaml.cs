using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media.Animation;
using FXRateDashboard.Utilities;
using FXRateDashboard.ViewModels;
using FXRateDashboard.Views;
using Microsoft.Extensions.DependencyInjection;
using DrawingRectangle = System.Drawing.Rectangle;
using Forms = System.Windows.Forms;
using WpfPoint = System.Windows.Point;
using WpfRect = System.Windows.Rect;
using WpfSize = System.Windows.Size;

namespace FXRateDashboard;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;
    private readonly IServiceProvider _serviceProvider;
    private bool _isInitialized;
    private bool _isSettingsDialogOpen;
    private bool _isApplyingModeTransition;

    public MainWindow(MainViewModel viewModel, IServiceProvider serviceProvider)
    {
        InitializeComponent();
        _viewModel = viewModel;
        _serviceProvider = serviceProvider;
        DataContext = _viewModel;

        Loaded += MainWindow_OnLoaded;
        Closing += MainWindow_OnClosing;
        LocationChanged += MainWindow_OnLocationChanged;
        IsVisibleChanged += MainWindow_OnIsVisibleChanged;
        _viewModel.RequestOpenSettings += ViewModel_OnRequestOpenSettings;
        _viewModel.PropertyChanged += ViewModel_OnPropertyChanged;
    }

    public void OpenSettingsFromTray()
    {
        if (!IsVisible)
        {
            RestoreFromTray();
        }

        _ = ShowSettingsDialogAsync();
    }

    public async Task PrepareForFirstShowAsync()
    {
        await _viewModel.EnsureSettingsLoadedAsync();
        ApplyModeState(animated: false);
        ApplyWindowPlacement();
    }

    public void ToggleVisibilityFromMenu()
    {
        if (IsVisible)
        {
            HideToTray();
        }
        else
        {
            RestoreFromTray();
        }
    }

    public async Task ToggleModeFromMenuAsync()
    {
        await _viewModel.ToggleCompactModeAsync();
    }

    public void HideToTray()
    {
        if (!IsVisible)
        {
            return;
        }

        Hide();
    }

    public void RestoreFromTray()
    {
        if (!IsVisible)
        {
            Show();
        }

        if (WindowState == WindowState.Minimized)
        {
            WindowState = WindowState.Normal;
        }

        Activate();
        Focus();
    }

    public void ShowContextMenuAtCursor()
    {
        var trayMenuWindow = _serviceProvider.GetRequiredService<TrayMenuWindow>();
        trayMenuWindow.ShowAtCursor();
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
        _viewModel.PropertyChanged -= ViewModel_OnPropertyChanged;
        await _viewModel.ShutdownAsync(Left, Top);
    }

    private void MainWindow_OnIsVisibleChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        _viewModel.SetWindowVisible(IsVisible);
    }

    private void ViewModel_OnRequestOpenSettings(object? sender, EventArgs e)
    {
        OpenSettingsFromTray();
    }

    private async void ViewModel_OnPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(MainViewModel.IsCompactMode))
        {
            await Dispatcher.InvokeAsync(() => ApplyModeState(animated: IsLoaded && IsVisible));
        }
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

    private void Window_OnPreviewMouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        e.Handled = true;
        ShowContextMenuAtCursor();
    }

    private async void Window_OnPreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount < 2)
        {
            return;
        }

        e.Handled = true;
        await ToggleModeFromMenuAsync();
    }

    private void ApplyModeState(bool animated)
    {
        var targetWidth = _viewModel.TargetWindowWidth;
        var targetHeight = _viewModel.TargetWindowHeight;
        var targetPosition = CalculateTargetPosition(targetWidth, targetHeight);

        if (!animated || _isApplyingModeTransition)
        {
            ApplyGridModeState(_viewModel.IsCompactMode);
            Left = targetPosition.X;
            Top = targetPosition.Y;
            Width = targetWidth;
            Height = targetHeight;
            MinWidth = targetWidth;
            MaxWidth = targetWidth;
            MinHeight = targetHeight;
            MaxHeight = targetHeight;
            ChartPanel.Visibility = _viewModel.IsCompactMode ? Visibility.Collapsed : Visibility.Visible;
            FooterPanel.Visibility = _viewModel.IsCompactMode ? Visibility.Collapsed : Visibility.Visible;
            CompactSourceText.Visibility = _viewModel.IsCompactMode ? Visibility.Visible : Visibility.Collapsed;
            ChartPanel.Opacity = _viewModel.IsCompactMode ? 0 : 1;
            FooterPanel.Opacity = _viewModel.IsCompactMode ? 0 : 1;
            CompactSourceText.Opacity = _viewModel.IsCompactMode ? 1 : 0;
            return;
        }

        _isApplyingModeTransition = true;
        MinWidth = 0;
        MaxWidth = double.PositiveInfinity;
        MinHeight = 0;
        MaxHeight = double.PositiveInfinity;

        if (targetWidth > Width || targetHeight > Height)
        {
            Left = targetPosition.X;
            Top = targetPosition.Y;
        }

        if (_viewModel.IsCompactMode)
        {
            CompactSourceText.Visibility = Visibility.Visible;
            AnimateOpacity(CompactSourceText, 1, 220);
            AnimateOpacity(ChartPanel, 0, 220);
            AnimateOpacity(FooterPanel, 0, 220);
        }
        else
        {
            ApplyGridModeState(isCompactMode: false);
            CompactSourceText.Visibility = Visibility.Visible;
            ChartPanel.Visibility = Visibility.Visible;
            FooterPanel.Visibility = Visibility.Visible;
            ChartPanel.Opacity = 0;
            FooterPanel.Opacity = 0;
            AnimateOpacity(CompactSourceText, 0, 180);
            AnimateOpacity(ChartPanel, 1, 260);
            AnimateOpacity(FooterPanel, 1, 260);
        }

        var widthAnimation = CreateSizeAnimation(targetWidth);
        var heightAnimation = CreateSizeAnimation(targetHeight);
        heightAnimation.Completed += (_, _) =>
        {
            ApplyGridModeState(_viewModel.IsCompactMode);
            ChartPanel.Visibility = _viewModel.IsCompactMode ? Visibility.Collapsed : Visibility.Visible;
            FooterPanel.Visibility = _viewModel.IsCompactMode ? Visibility.Collapsed : Visibility.Visible;
            CompactSourceText.Visibility = _viewModel.IsCompactMode ? Visibility.Visible : Visibility.Collapsed;
            CompactSourceText.Opacity = _viewModel.IsCompactMode ? 1 : 0;
            Left = targetPosition.X;
            Top = targetPosition.Y;
            Width = targetWidth;
            Height = targetHeight;
            MinWidth = targetWidth;
            MaxWidth = targetWidth;
            MinHeight = targetHeight;
            MaxHeight = targetHeight;
            _isApplyingModeTransition = false;
        };

        BeginAnimation(WidthProperty, widthAnimation, HandoffBehavior.SnapshotAndReplace);
        BeginAnimation(HeightProperty, heightAnimation, HandoffBehavior.SnapshotAndReplace);
    }

    private WpfPoint CalculateTargetPosition(double targetWidth, double targetHeight)
    {
        var monitor = Forms.Screen.FromRectangle(new DrawingRectangle(
            (int)Math.Round(Left),
            (int)Math.Round(Top),
            Math.Max(1, (int)Math.Round(ActualWidth > 0 ? ActualWidth : Width)),
            Math.Max(1, (int)Math.Round(ActualHeight > 0 ? ActualHeight : Height))));

        var workArea = monitor.WorkingArea;
        var workAreaRect = new WpfRect(workArea.Left, workArea.Top, workArea.Width, workArea.Height);
        var currentBounds = new WpfRect(Left, Top, Width, Height);

        return WindowPlacementHelper.CalculateClampedTopLeft(
            workAreaRect,
            currentBounds,
            new WpfSize(targetWidth, targetHeight));
    }

    private void ApplyGridModeState(bool isCompactMode)
    {
        ChartRow.Height = isCompactMode
            ? new GridLength(0)
            : new GridLength(1, GridUnitType.Star);
        FooterRow.Height = isCompactMode
            ? new GridLength(0)
            : GridLength.Auto;
    }

    private static DoubleAnimation CreateSizeAnimation(double targetValue)
    {
        return new DoubleAnimation
        {
            To = targetValue,
            Duration = TimeSpan.FromMilliseconds(280),
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseInOut }
        };
    }
    private static void AnimateOpacity(UIElement element, double targetOpacity, int durationMs)
    {
        var animation = new DoubleAnimation
        {
            To = targetOpacity,
            Duration = TimeSpan.FromMilliseconds(durationMs),
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseInOut }
        };

        if (targetOpacity > 0 && element.Visibility != Visibility.Visible)
        {
            element.Visibility = Visibility.Visible;
        }

        element.BeginAnimation(OpacityProperty, animation, HandoffBehavior.SnapshotAndReplace);
    }
}
