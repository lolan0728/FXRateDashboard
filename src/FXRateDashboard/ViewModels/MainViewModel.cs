using System.Globalization;
using System.Net;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using FXRateDashboard.Models;
using FXRateDashboard.Services;
using FXRateDashboard.Utilities;
using BrushConverter = System.Windows.Media.BrushConverter;
using MediaColorConverter = System.Windows.Media.ColorConverter;
using Duration = System.Windows.Duration;
using MediaColor = System.Windows.Media.Color;
using SolidColorBrush = System.Windows.Media.SolidColorBrush;

namespace FXRateDashboard.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private static readonly MediaColor PositiveColorValue = ParseColor("#6C9A54");
    private static readonly MediaColor NegativeColorValue = ParseColor("#D97A68");
    private static readonly MediaColor WarningColorValue = ParseColor("#C69200");
    private static readonly MediaColor NeutralColorValue = ParseColor("#163300");
    private static readonly MediaColor OfflineTrendColorValue = ParseColor("#8E9689");
    private static readonly MediaColor OnlinePanelBackgroundColorValue = ParseColor("#FBFCF8");
    private static readonly MediaColor OfflinePanelBackgroundColorValue = ParseColor("#D2D9CA");
    private static readonly MediaColor OnlineSurfaceAltColorValue = ParseColor("#F2F7EA");
    private static readonly MediaColor OfflineSurfaceAltColorValue = ParseColor("#E1E5DE");
    private static readonly MediaColor OnlineAccentColorValue = ParseColor("#9FE870");
    private static readonly MediaColor OfflineAccentColorValue = ParseColor("#B7BEB2");
    private static readonly MediaColor OnlinePrimaryTextColorValue = ParseColor("#163300");
    private static readonly MediaColor OfflinePrimaryTextColorValue = ParseColor("#52584F");
    private static readonly MediaColor OnlineMutedTextColorValue = ParseColor("#6A745F");
    private static readonly MediaColor OfflineMutedTextColorValue = ParseColor("#7D8479");
    private static readonly MediaColor OnlineStatusChipBackgroundColorValue = ParseColor("#14FFFFFF");
    private static readonly MediaColor OfflineStatusChipBackgroundColorValue = ParseColor("#66FFFFFF");
    private static readonly Duration PaletteAnimationDuration = new(TimeSpan.FromMilliseconds(500));

    private readonly ISettingsStore _settingsStore;
    private readonly ICacheStore _cacheStore;
    private readonly IWiseRateClient _wiseRateClient;
    private readonly IRateQueryMapper _rateQueryMapper;
    private readonly ITokenProtector _tokenProtector;
    private readonly IUiDispatcher _uiDispatcher;
    private readonly IStartupLaunchService _startupLaunchService;
    private readonly SemaphoreSlim _currentRefreshGate = new(1, 1);
    private readonly SemaphoreSlim _historyRefreshGate = new(1, 1);

    private AppSettings _settings = new();
    private RateSeriesSnapshot? _snapshot;
    private CancellationTokenSource? _pollingCts;
    private bool _settingsLoaded;

    public MainViewModel(
        ISettingsStore settingsStore,
        ICacheStore cacheStore,
        IWiseRateClient wiseRateClient,
        IRateQueryMapper rateQueryMapper,
        ITokenProtector tokenProtector,
        IUiDispatcher uiDispatcher,
        IStartupLaunchService startupLaunchService)
    {
        _settingsStore = settingsStore;
        _cacheStore = cacheStore;
        _wiseRateClient = wiseRateClient;
        _rateQueryMapper = rateQueryMapper;
        _tokenProtector = tokenProtector;
        _uiDispatcher = uiDispatcher;
        _startupLaunchService = startupLaunchService;

        SelectRangeCommand = new AsyncRelayCommand<TimeRangePreset>(SelectRangeAsync);
    }

    public event EventHandler? RequestOpenSettings;

    public IAsyncRelayCommand<TimeRangePreset> SelectRangeCommand { get; }

    [ObservableProperty]
    private string _pairLabel = "USD/CNY";

    [ObservableProperty]
    private string _currentRateDisplay = "--";

    [ObservableProperty]
    private string _quoteCurrencyCode = "CNY";

    [ObservableProperty]
    private string _changeDisplay = "+0.0000";

    [ObservableProperty]
    private string _changePercentDisplay = "+0.00%";

    [ObservableProperty]
    private string _lastUpdatedDisplay = "Updated at: --";

    [ObservableProperty]
    private string _statusMessage = "Updated at: --";

    [ObservableProperty]
    private string _footerHint = "Wise";

    [ObservableProperty]
    private bool _alwaysOnTop;

    [ObservableProperty]
    private bool _isPositionLocked;

    [ObservableProperty]
    private double _panelOpacity = 1.0;

    [ObservableProperty]
    private TimeRangePreset _activeRange = TimeRangePreset.Day;

    [ObservableProperty]
    private IReadOnlyList<RatePoint> _chartPoints = Array.Empty<RatePoint>();

    [ObservableProperty]
    private SolidColorBrush _trendBrush = CreateAnimatedBrush(OfflineTrendColorValue);

    [ObservableProperty]
    private SolidColorBrush _statusBrush = CreateAnimatedBrush(WarningColorValue);

    [ObservableProperty]
    private SolidColorBrush _panelBackgroundBrush = CreateAnimatedBrush(OfflinePanelBackgroundColorValue);

    [ObservableProperty]
    private SolidColorBrush _chartCardBackgroundBrush = CreateAnimatedBrush(OfflineSurfaceAltColorValue);

    [ObservableProperty]
    private SolidColorBrush _accentBrush = CreateAnimatedBrush(OfflineAccentColorValue);

    [ObservableProperty]
    private SolidColorBrush _primaryTextBrush = CreateAnimatedBrush(OfflinePrimaryTextColorValue);

    [ObservableProperty]
    private SolidColorBrush _mutedTextBrush = CreateAnimatedBrush(OfflineMutedTextColorValue);

    [ObservableProperty]
    private SolidColorBrush _statusChipBackgroundBrush = CreateAnimatedBrush(OfflineStatusChipBackgroundColorValue);

    [ObservableProperty]
    private bool _isOffline = true;

    [ObservableProperty]
    private bool _isCompactMode;

    [ObservableProperty]
    private bool _isWindowVisible = true;

    public string ToggleModeMenuText => IsCompactMode ? "Restore Full Mode" : "Compact Mode";

    public string ToggleVisibilityMenuText => IsWindowVisible ? "Hide Window" : "Show Window";

    public Visibility CompactSourceVisibility => IsCompactMode ? Visibility.Visible : Visibility.Collapsed;

    public Visibility FullFooterVisibility => IsCompactMode ? Visibility.Collapsed : Visibility.Visible;

    public string StatusChipText => IsCompactMode ? ExtractCompactStatusText(StatusMessage) : StatusMessage;

    public double TargetWindowWidth => IsCompactMode ? 236d : 404d;

    public double TargetWindowHeight => IsCompactMode ? 122d : 410d;

    public Thickness WidgetOuterMargin => IsCompactMode ? new Thickness(7) : new Thickness(10);

    public CornerRadius WidgetCornerRadius => IsCompactMode ? new CornerRadius(24) : new CornerRadius(28);

    public Thickness WidgetContentPadding => IsCompactMode ? new Thickness(9, 9, 9, 8) : new Thickness(18);

    public double PairLabelFontSize => IsCompactMode ? 10d : 12d;

    public Thickness PairLabelPadding => IsCompactMode ? new Thickness(7, 4, 7, 4) : new Thickness(10, 5, 10, 5);

    public Thickness StatusChipPadding => IsCompactMode ? new Thickness(7, 3, 7, 3) : new Thickness(8, 4, 8, 4);

    public double StatusFontSize => IsCompactMode ? 9d : 11d;

    public double StatusChipMinWidth => IsCompactMode ? 40d : 0d;

    public Thickness ValueSectionMargin => IsCompactMode ? new Thickness(0, 4, 0, 0) : new Thickness(0, 8, 0, 0);

    public double CurrentValueFontSize => IsCompactMode ? 27d : 42d;

    public Thickness QuoteCurrencyMargin => IsCompactMode ? new Thickness(6, 8, 0, 0) : new Thickness(10, 16, 0, 0);

    public double QuoteCurrencyFontSize => IsCompactMode ? 10d : 13d;

    public double ChangeFontSize => IsCompactMode ? 11d : 15d;

    public Thickness ChangeGroupMargin => IsCompactMode ? new Thickness(6, 0, 0, 0) : new Thickness(4, 0, 0, 0);

    public Thickness ChangeRowMargin => IsCompactMode ? new Thickness(0, 8, 0, 0) : new Thickness(0);

    public Thickness CompactSourceMargin => IsCompactMode ? new Thickness(10, 0, 6, 0) : new Thickness(12, 0, 0, 0);

    public double CompactSourceFontSize => IsCompactMode ? 10d : 11d;

    public Thickness FooterSourceMargin => IsCompactMode ? new Thickness(12, 0, 0, 0) : new Thickness(18, 0, 0, 0);

    public async Task InitializeAsync()
    {
        await EnsureSettingsLoadedAsync();

        await RestoreCachedSnapshotAsync(presentAsOffline: true);

        if (!HasToken())
        {
            await SetOfflineStateAsync(openSettings: true);
            return;
        }

        await BootstrapAndStartPollingAsync(openSettingsOnFailure: true);
    }

    public AppSettings CreateEditableSettings()
    {
        return _settings.Clone();
    }

    public async Task EnsureSettingsLoadedAsync()
    {
        if (_settingsLoaded)
        {
            return;
        }

        _settings = await _settingsStore.LoadAsync();
        _settings.Normalize();
        _settingsLoaded = true;
        await ApplySettingsToViewAsync();
    }

    public (double? Left, double? Top) GetSavedWindowPlacement()
    {
        return (_settings.WindowLeft, _settings.WindowTop);
    }

    public void UpdateWindowPosition(double left, double top)
    {
        if (_settings.LockPosition)
        {
            return;
        }

        _settings.WindowLeft = left;
        _settings.WindowTop = top;
    }

    public async Task<(bool Success, string ErrorMessage)> ApplySettingsAsync(AppSettings newSettings)
    {
        var normalized = newSettings.Clone();
        normalized.Normalize();

        var currentToken = NormalizeStoredOrRawToken(_settings.EncryptedWiseToken);
        var requestedToken = NormalizeStoredOrRawToken(normalized.EncryptedWiseToken);
        var tokenChanged = !string.Equals(currentToken, requestedToken, StringComparison.Ordinal);
        var pairChanged = normalized.BaseCurrency != _settings.BaseCurrency ||
                          normalized.QuoteCurrency != _settings.QuoteCurrency ||
                          normalized.ActiveRange != _settings.ActiveRange;
        var refreshChanged = normalized.RefreshSeconds != _settings.RefreshSeconds;
        var settingsChanged = pairChanged ||
                              tokenChanged ||
                              normalized.BaseAmount != _settings.BaseAmount ||
                              refreshChanged ||
                              normalized.LockPosition != _settings.LockPosition ||
                              normalized.LaunchAtStartup != _settings.LaunchAtStartup;

        if (tokenChanged && !string.IsNullOrWhiteSpace(requestedToken))
        {
            try
            {
                await _wiseRateClient.GetCurrentRateAsync(
                    normalized.BaseCurrency,
                    normalized.QuoteCurrency,
                    requestedToken,
                    CancellationToken.None);
            }
            catch (WiseApiException ex)
            {
                return (false, ex.Message);
            }
            catch (Exception ex)
            {
                return (false, $"Unable to validate the Wise token: {ex.Message}");
            }
        }

        normalized.EncryptedWiseToken = string.IsNullOrWhiteSpace(requestedToken)
            ? null
            : _tokenProtector.Protect(requestedToken);

        if (!settingsChanged)
        {
            await _settingsStore.SaveAsync(_settings);
            return (true, string.Empty);
        }

        StopPolling();

        _settings = normalized;
        await _settingsStore.SaveAsync(_settings);
        await _startupLaunchService.SetEnabledAsync(_settings.LaunchAtStartup);
        await ApplySettingsToViewAsync();

        if (_snapshot is not null && !pairChanged && !tokenChanged)
        {
            await PublishSnapshotAsync(_snapshot, FooterHint, presentAsOffline: IsOffline);
        }
        else if (pairChanged)
        {
            await RestoreCachedSnapshotAsync(presentAsOffline: IsOffline);
        }

        if (HasToken())
        {
            if (pairChanged || tokenChanged)
            {
                _ = BootstrapAndStartPollingAsync(openSettingsOnFailure: false);
            }
            else
            {
                StartPollingLoops();
            }
        }
        else
        {
            await SetOfflineStateAsync(openSettings: false);
        }

        return (true, string.Empty);
    }

    public async Task ShutdownAsync(double left, double top)
    {
        UpdateWindowPosition(left, top);
        StopPolling();
        await _settingsStore.SaveAsync(_settings);
    }

    private async Task ApplySettingsToViewAsync()
    {
        await _uiDispatcher.InvokeAsync(() =>
        {
            PairLabel = BuildPairLabel(_settings);
            QuoteCurrencyCode = _settings.QuoteCurrency;
            ActiveRange = _settings.ActiveRange;
            IsCompactMode = _settings.IsCompactMode;
            AlwaysOnTop = false;
            IsPositionLocked = _settings.LockPosition;
            PanelOpacity = 1.0;
        });
    }

    private async Task RestoreCachedSnapshotAsync(bool presentAsOffline)
    {
        var cachedSnapshot = await _cacheStore.LoadSnapshotAsync(_settings.Pair, _settings.ActiveRange);
        if (cachedSnapshot is null)
        {
            return;
        }

        cachedSnapshot.IsStale = true;
        await PublishSnapshotAsync(cachedSnapshot, "Cached", presentAsOffline);
    }

    private async Task BootstrapAndStartPollingAsync(bool openSettingsOnFailure)
    {
        try
        {
            await RefreshHistoricalAsync(CancellationToken.None);
            StartPollingLoops();
        }
        catch (WiseApiException ex) when (ex.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized)
        {
            await SetOfflineStateAsync(openSettingsOnFailure);
        }
        catch (Exception)
        {
            await SetOfflineStateAsync(openSettingsOnFailure);
        }
    }

    private void StartPollingLoops()
    {
        StopPolling();

        _pollingCts = new CancellationTokenSource();
        _ = RunCurrentRateLoopAsync(_pollingCts.Token);
        _ = RunHistoryLoopAsync(_pollingCts.Token);
    }

    private void StopPolling()
    {
        if (_pollingCts is null)
        {
            return;
        }

        _pollingCts.Cancel();
        _pollingCts.Dispose();
        _pollingCts = null;
    }

    private async Task RunCurrentRateLoopAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(_settings.RefreshSeconds));

        try
        {
            while (await timer.WaitForNextTickAsync(cancellationToken))
            {
                await TryRefreshCurrentAsync(cancellationToken);
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private async Task RunHistoryLoopAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(15));

        try
        {
            while (await timer.WaitForNextTickAsync(cancellationToken))
            {
                await TryRefreshHistoryAsync(cancellationToken);
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private async Task TryRefreshCurrentAsync(CancellationToken cancellationToken)
    {
        try
        {
            await RefreshCurrentAsync(cancellationToken);
        }
        catch (WiseApiException ex) when (ex.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized)
        {
            StopPolling();
            await SetOfflineStateAsync(openSettings: true);
        }
        catch (Exception)
        {
            await MarkSnapshotStaleAsync();
        }
    }

    private async Task TryRefreshHistoryAsync(CancellationToken cancellationToken)
    {
        try
        {
            await RefreshHistoricalAsync(cancellationToken);
        }
        catch (WiseApiException ex) when (ex.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized)
        {
            StopPolling();
            await SetOfflineStateAsync(openSettings: true);
        }
        catch (Exception)
        {
            await MarkSnapshotStaleAsync();
        }
    }

    private async Task RefreshCurrentAsync(CancellationToken cancellationToken)
    {
        await _currentRefreshGate.WaitAsync(cancellationToken);
        try
        {
            var token = GetTokenOrThrow();
            var currentRate = await _wiseRateClient.GetCurrentRateAsync(
                _settings.BaseCurrency,
                _settings.QuoteCurrency,
                token,
                cancellationToken);

            var points = _snapshot?.Points ?? [];
            var merged = RateMath.AppendOrReplaceLatest(points, currentRate);
            var snapshot = RateMath.CreateSnapshot(
                _settings.Pair,
                _settings.ActiveRange,
                merged,
                currentRate.Rate,
                currentRate.TimestampUtc,
                isStale: false);

            await _cacheStore.SaveSnapshotAsync(snapshot, cancellationToken);
            await PublishSnapshotAsync(snapshot, "Wise");
        }
        finally
        {
            _currentRefreshGate.Release();
        }
    }

    private async Task RefreshHistoricalAsync(CancellationToken cancellationToken)
    {
        await _historyRefreshGate.WaitAsync(cancellationToken);
        try
        {
            var token = GetTokenOrThrow();
            var query = _rateQueryMapper.MapHistoryQuery(_settings.ActiveRange);

            var history = await _wiseRateClient.GetHistoricalRatesAsync(
                _settings.BaseCurrency,
                _settings.QuoteCurrency,
                token,
                query.FromUtc,
                query.ToUtc,
                query.Group,
                cancellationToken);

            var currentRate = await _wiseRateClient.GetCurrentRateAsync(
                _settings.BaseCurrency,
                _settings.QuoteCurrency,
                token,
                cancellationToken);

            var merged = RateMath.AppendOrReplaceLatest(history, currentRate);
            var snapshot = RateMath.CreateSnapshot(
                _settings.Pair,
                _settings.ActiveRange,
                merged,
                currentRate.Rate,
                currentRate.TimestampUtc,
                isStale: false);

            await _cacheStore.SaveSnapshotAsync(snapshot, cancellationToken);
            await PublishSnapshotAsync(snapshot, "Wise");
        }
        finally
        {
            _historyRefreshGate.Release();
        }
    }

    private async Task SelectRangeAsync(TimeRangePreset range)
    {
        if (_settings.ActiveRange == range && _snapshot?.Range == range)
        {
            return;
        }

        _settings.ActiveRange = range;
        await _settingsStore.SaveAsync(_settings);
        await ApplySettingsToViewAsync();
        await RestoreCachedSnapshotAsync(presentAsOffline: IsOffline);

        if (HasToken())
        {
            await TryRefreshHistoryAsync(CancellationToken.None);
        }
    }

    private async Task PublishSnapshotAsync(RateSeriesSnapshot snapshot, string footerHint, bool presentAsOffline = false)
    {
        _snapshot = snapshot.Clone();
        var downsampled = RateMath.Downsample(snapshot.Points, 240);
        var scaledChartPoints = RateMath.ScalePoints(downsampled, _settings.BaseAmount);
        var convertedCurrent = snapshot.CurrentRate * _settings.BaseAmount;
        var convertedChange = snapshot.ChangeAbsolute * _settings.BaseAmount;
        var updatedLabel = FormatUpdatedAt(snapshot.AsOfUtc);

        await _uiDispatcher.InvokeAsync(() =>
        {
            PairLabel = BuildPairLabel(_settings);
            QuoteCurrencyCode = _settings.QuoteCurrency;
            ActiveRange = snapshot.Range;
            ChartPoints = scaledChartPoints;
            CurrentRateDisplay = RateMath.FormatDisplayAmount(convertedCurrent);
            ChangeDisplay = RateMath.FormatSignedAmount(convertedChange);
            ChangePercentDisplay = $"{(snapshot.ChangePercent > 0 ? "+" : string.Empty)}{snapshot.ChangePercent:0.00}%";
            LastUpdatedDisplay = updatedLabel;
            StatusMessage = updatedLabel;
            FooterHint = footerHint;
            ApplyPalette(presentAsOffline, snapshot.ChangeAbsolute);
            IsOffline = presentAsOffline;
        });
    }

    private async Task MarkSnapshotStaleAsync()
    {
        if (_snapshot is null)
        {
            await SetOfflineStateAsync(openSettings: false);
            return;
        }

        var staleSnapshot = _snapshot.Clone();
        staleSnapshot.IsStale = true;
        await PublishSnapshotAsync(staleSnapshot, "Cached", presentAsOffline: true);
    }

    private async Task SetOfflineStateAsync(bool openSettings)
    {
        await _uiDispatcher.InvokeAsync(() =>
        {
            var updatedLabel = _snapshot is null ? FormatUpdatedAt(null) : FormatUpdatedAt(_snapshot.AsOfUtc);
            StatusMessage = updatedLabel;
            LastUpdatedDisplay = updatedLabel;
            FooterHint = "Wise";
            ApplyPalette(isOffline: true, changeAbsolute: _snapshot?.ChangeAbsolute);
            IsOffline = true;
        });

        if (openSettings)
        {
            RequestOpenSettings?.Invoke(this, EventArgs.Empty);
        }
    }

    private bool HasToken()
    {
        return !string.IsNullOrWhiteSpace(NormalizeStoredOrRawToken(_settings.EncryptedWiseToken));
    }

    public async Task ToggleCompactModeAsync()
    {
        _settings.IsCompactMode = !_settings.IsCompactMode;
        await _settingsStore.SaveAsync(_settings);
        await _uiDispatcher.InvokeAsync(() => IsCompactMode = _settings.IsCompactMode);
    }

    public void SetWindowVisible(bool isVisible)
    {
        if (IsWindowVisible == isVisible)
        {
            return;
        }

        IsWindowVisible = isVisible;
    }

    private string GetTokenOrThrow()
    {
        var token = NormalizeStoredOrRawToken(_settings.EncryptedWiseToken);
        if (string.IsNullOrWhiteSpace(token))
        {
            throw new WiseApiException("Please configure a Wise token from the tray menu first.");
        }

        return token;
    }

    private string? NormalizeStoredOrRawToken(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var unprotected = _tokenProtector.Unprotect(value);
        return NormalizeTokenInput(unprotected ?? value);
    }

    private static string? NormalizeTokenInput(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var token = value.Trim();

        if (token.StartsWith("Authorization:", StringComparison.OrdinalIgnoreCase))
        {
            token = token["Authorization:".Length..].Trim();
        }

        if (token.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            token = token["Bearer ".Length..].Trim();
        }

        token = token.Trim().Trim('"');
        return string.IsNullOrWhiteSpace(token) ? null : token;
    }

    private void ApplyPalette(bool isOffline, decimal? changeAbsolute)
    {
        AnimateBrush(
            TrendBrush,
            isOffline
                ? OfflineTrendColorValue
                : (changeAbsolute ?? 0m) >= 0
                    ? PositiveColorValue
                    : NegativeColorValue);
        AnimateBrush(StatusBrush, isOffline ? WarningColorValue : NeutralColorValue);
        AnimateBrush(PanelBackgroundBrush, isOffline ? OfflinePanelBackgroundColorValue : OnlinePanelBackgroundColorValue);
        AnimateBrush(ChartCardBackgroundBrush, isOffline ? OfflineSurfaceAltColorValue : OnlineSurfaceAltColorValue);
        AnimateBrush(AccentBrush, isOffline ? OfflineAccentColorValue : OnlineAccentColorValue);
        AnimateBrush(PrimaryTextBrush, isOffline ? OfflinePrimaryTextColorValue : OnlinePrimaryTextColorValue);
        AnimateBrush(MutedTextBrush, isOffline ? OfflineMutedTextColorValue : OnlineMutedTextColorValue);
        AnimateBrush(StatusChipBackgroundBrush, isOffline ? OfflineStatusChipBackgroundColorValue : OnlineStatusChipBackgroundColorValue);
    }

    private static void AnimateBrush(SolidColorBrush brush, MediaColor targetColor)
    {
        var animation = new ColorAnimation
        {
            To = targetColor,
            Duration = PaletteAnimationDuration,
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseInOut }
        };
        brush.BeginAnimation(SolidColorBrush.ColorProperty, animation, HandoffBehavior.SnapshotAndReplace);
    }

    private static SolidColorBrush CreateAnimatedBrush(MediaColor color)
    {
        return new SolidColorBrush(color);
    }

    private static MediaColor ParseColor(string hex)
    {
        return (MediaColor)MediaColorConverter.ConvertFromString(hex)!;
    }

    private static string BuildPairLabel(AppSettings settings)
    {
        return $"{settings.BaseAmount.ToString("0.####", CultureInfo.InvariantCulture)} {settings.BaseCurrency}/{settings.QuoteCurrency}";
    }

    private static string FormatUpdatedAt(DateTimeOffset? timestampUtc)
    {
        return timestampUtc.HasValue
            ? $"Updated at: {timestampUtc.Value.ToLocalTime():HH:mm}"
            : "Updated at: --";
    }

    private static string ExtractCompactStatusText(string? statusMessage)
    {
        if (string.IsNullOrWhiteSpace(statusMessage))
        {
            return "--";
        }

        const string prefix = "Updated at:";
        if (statusMessage.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
        {
            var compactTime = statusMessage[prefix.Length..].Trim();
            return string.IsNullOrWhiteSpace(compactTime) ? "--" : compactTime;
        }

        return statusMessage.Trim();
    }

    partial void OnStatusMessageChanged(string value)
    {
        OnPropertyChanged(nameof(StatusChipText));
    }

    partial void OnIsCompactModeChanged(bool value)
    {
        OnPropertyChanged(nameof(StatusChipText));
        OnPropertyChanged(nameof(ToggleModeMenuText));
        OnPropertyChanged(nameof(CompactSourceVisibility));
        OnPropertyChanged(nameof(FullFooterVisibility));
        OnPropertyChanged(nameof(TargetWindowWidth));
        OnPropertyChanged(nameof(TargetWindowHeight));
        OnPropertyChanged(nameof(WidgetOuterMargin));
        OnPropertyChanged(nameof(WidgetCornerRadius));
        OnPropertyChanged(nameof(WidgetContentPadding));
        OnPropertyChanged(nameof(PairLabelFontSize));
        OnPropertyChanged(nameof(PairLabelPadding));
        OnPropertyChanged(nameof(StatusChipPadding));
        OnPropertyChanged(nameof(StatusFontSize));
        OnPropertyChanged(nameof(StatusChipMinWidth));
        OnPropertyChanged(nameof(ValueSectionMargin));
        OnPropertyChanged(nameof(CurrentValueFontSize));
        OnPropertyChanged(nameof(QuoteCurrencyMargin));
        OnPropertyChanged(nameof(QuoteCurrencyFontSize));
        OnPropertyChanged(nameof(ChangeFontSize));
        OnPropertyChanged(nameof(ChangeGroupMargin));
        OnPropertyChanged(nameof(ChangeRowMargin));
        OnPropertyChanged(nameof(CompactSourceMargin));
        OnPropertyChanged(nameof(CompactSourceFontSize));
        OnPropertyChanged(nameof(FooterSourceMargin));
    }

    partial void OnIsWindowVisibleChanged(bool value)
    {
        OnPropertyChanged(nameof(ToggleVisibilityMenuText));
    }
}
