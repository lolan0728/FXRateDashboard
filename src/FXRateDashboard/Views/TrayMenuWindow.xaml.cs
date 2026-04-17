using System.Windows;
using FXRateDashboard.ViewModels;
using Forms = System.Windows.Forms;

namespace FXRateDashboard.Views;

public partial class TrayMenuWindow : Window
{
    public event EventHandler? ToggleVisibilityRequested;
    public event EventHandler? ToggleModeRequested;
    public event EventHandler? ToggleClickThroughRequested;
    public event EventHandler? SettingsRequested;
    public event EventHandler? QuitRequested;

    public TrayMenuWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
        Deactivated += (_, _) => Hide();
    }

    public void ToggleAtCursor()
    {
        if (IsVisible)
        {
            Hide();
            return;
        }

        ShowAtCursor();
    }

    public void ShowAtCursor()
    {
        var cursor = Forms.Control.MousePosition;
        var workArea = Forms.Screen.GetWorkingArea(cursor);

        if (!IsVisible)
        {
            Show();
        }

        Activate();
        UpdateLayout();

        Left = Math.Min(cursor.X - ActualWidth + 12, workArea.Right - ActualWidth - 8);
        Top = Math.Min(cursor.Y - ActualHeight - 8, workArea.Bottom - ActualHeight - 8);

        Left = Math.Max(workArea.Left + 8, Left);
        Top = Math.Max(workArea.Top + 8, Top);
    }

    private void ToggleVisibilityButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        ToggleVisibilityRequested?.Invoke(this, EventArgs.Empty);
    }

    private void ToggleModeButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        ToggleModeRequested?.Invoke(this, EventArgs.Empty);
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        SettingsRequested?.Invoke(this, EventArgs.Empty);
    }

    private void ToggleClickThroughButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        ToggleClickThroughRequested?.Invoke(this, EventArgs.Empty);
    }

    private void QuitButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        QuitRequested?.Invoke(this, EventArgs.Empty);
    }
}
