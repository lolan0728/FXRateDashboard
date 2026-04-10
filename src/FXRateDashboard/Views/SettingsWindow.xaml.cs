using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using FXRateDashboard.Models;
using FXRateDashboard.ViewModels;
using Forms = System.Windows.Forms;

namespace FXRateDashboard.Views;

public partial class SettingsWindow : Window
{
    private readonly SettingsViewModel _viewModel;
    public Func<AppSettings, Task<(bool Success, string ErrorMessage)>>? SubmitSettingsAsync { get; set; }

    public SettingsWindow(SettingsViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = _viewModel;
    }

    public AppSettings? CreatedSettings { get; private set; }

    public void Load(AppSettings settings)
    {
        CreatedSettings = null;
        _viewModel.Load(settings);
        ClearError();
        UpdateTokenClearButtonVisibility();
    }

    public void PositionNearOwner(Window owner)
    {
        Owner = owner;
        WindowStartupLocation = WindowStartupLocation.Manual;
        Loaded -= SettingsWindow_OnLoaded;
        Loaded += SettingsWindow_OnLoaded;
    }

    private void TitleBar_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void CloseButton_OnClick(object sender, RoutedEventArgs e)
    {
        CreatedSettings = null;
        Close();
    }

    private void CancelButton_OnClick(object sender, RoutedEventArgs e)
    {
        CreatedSettings = null;
        Close();
    }

    private async void SaveButton_OnClick(object sender, RoutedEventArgs e)
    {
        if (!_viewModel.TryBuildSettings(out var settings, out var validationError))
        {
            ShowError(validationError);
            return;
        }

        ClearError();

        if (SubmitSettingsAsync is not null)
        {
            var submitResult = await SubmitSettingsAsync(settings);
            if (!submitResult.Success)
            {
                ShowError(submitResult.ErrorMessage);
                return;
            }
        }

        CreatedSettings = settings;
        Close();
    }

    private void ClearTokenButton_OnClick(object sender, RoutedEventArgs e)
    {
        _viewModel.ApiTokenText = string.Empty;
        ApiTokenBox.Focus();
        UpdateTokenClearButtonVisibility();
    }

    private void ApiTokenBox_OnTextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        UpdateTokenClearButtonVisibility();
    }

    private void ApiTokenBox_OnFocusChanged(object sender, RoutedEventArgs e)
    {
        UpdateTokenClearButtonVisibility();
    }

    private void UpdateTokenClearButtonVisibility()
    {
        ClearTokenButton.Visibility = ApiTokenBox.IsKeyboardFocused && !string.IsNullOrEmpty(ApiTokenBox.Text)
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    public void ShowError(string message)
    {
        ValidationMessageText.Text = message;
        ValidationBanner.Visibility = Visibility.Visible;
    }

    public void ClearError()
    {
        ValidationMessageText.Text = string.Empty;
        ValidationBanner.Visibility = Visibility.Collapsed;
    }

    private void SettingsWindow_OnLoaded(object sender, RoutedEventArgs e)
    {
        Loaded -= SettingsWindow_OnLoaded;

        if (Owner is null)
        {
            return;
        }

        var ownerHandle = new WindowInteropHelper(Owner).Handle;
        var screen = ownerHandle != IntPtr.Zero
            ? Forms.Screen.FromHandle(ownerHandle)
            : Forms.Screen.PrimaryScreen ?? Forms.Screen.AllScreens.First();

        var workArea = screen.WorkingArea;
        var gap = 12d;
        var dialogWidth = ActualWidth > 0 ? ActualWidth : Width;
        var dialogHeight = ActualHeight > 0 ? ActualHeight : Math.Max(Height, MinHeight);

        var leftCandidate = Owner.Left - dialogWidth - gap;
        var rightCandidate = Owner.Left + Owner.Width + gap;

        if (leftCandidate >= workArea.Left + gap)
        {
            Left = leftCandidate;
        }
        else if (rightCandidate + dialogWidth <= workArea.Right - gap)
        {
            Left = rightCandidate;
        }
        else
        {
            Left = Math.Clamp(Owner.Left + ((Owner.Width - dialogWidth) / 2), workArea.Left + gap, workArea.Right - dialogWidth - gap);
        }

        var preferredTop = Owner.Top + Math.Max((Owner.Height - dialogHeight) / 2, 0);
        Top = Math.Clamp(preferredTop, workArea.Top + gap, workArea.Bottom - dialogHeight - gap);
    }
}
