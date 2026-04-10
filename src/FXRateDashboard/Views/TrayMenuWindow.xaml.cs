using System.Windows;
using Forms = System.Windows.Forms;

namespace FXRateDashboard.Views;

public partial class TrayMenuWindow : Window
{
    public event EventHandler? ShowWidgetRequested;
    public event EventHandler? SettingsRequested;
    public event EventHandler? QuitRequested;

    public TrayMenuWindow()
    {
        InitializeComponent();
        Deactivated += (_, _) => Hide();
    }

    public void ToggleAtCursor()
    {
        if (IsVisible)
        {
            Hide();
            return;
        }

        var cursor = Forms.Control.MousePosition;
        var workArea = Forms.Screen.GetWorkingArea(cursor);

        Show();
        Activate();
        UpdateLayout();

        Left = Math.Min(cursor.X - ActualWidth + 12, workArea.Right - ActualWidth - 8);
        Top = Math.Min(cursor.Y - ActualHeight - 8, workArea.Bottom - ActualHeight - 8);

        Left = Math.Max(workArea.Left + 8, Left);
        Top = Math.Max(workArea.Top + 8, Top);
    }

    private void ShowWidgetButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        ShowWidgetRequested?.Invoke(this, EventArgs.Empty);
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        SettingsRequested?.Invoke(this, EventArgs.Empty);
    }

    private void QuitButton_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        QuitRequested?.Invoke(this, EventArgs.Empty);
    }
}
