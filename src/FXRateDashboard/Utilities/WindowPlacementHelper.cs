using Point = System.Windows.Point;
using Rect = System.Windows.Rect;
using Size = System.Windows.Size;

namespace FXRateDashboard.Utilities;

public static class WindowPlacementHelper
{
    private const double EdgeAnchorThreshold = 24;

    public static Point CalculateClampedTopLeft(Rect workArea, Rect currentBounds, Size targetSize)
    {
        var isAnchoredToRight = workArea.Right - currentBounds.Right <= EdgeAnchorThreshold;
        var isAnchoredToBottom = workArea.Bottom - currentBounds.Bottom <= EdgeAnchorThreshold;

        var targetLeft = isAnchoredToRight
            ? currentBounds.Right - targetSize.Width
            : currentBounds.Left;
        var targetTop = isAnchoredToBottom
            ? currentBounds.Bottom - targetSize.Height
            : currentBounds.Top;

        if (targetLeft + targetSize.Width > workArea.Right)
        {
            targetLeft = workArea.Right - targetSize.Width;
        }

        if (targetTop + targetSize.Height > workArea.Bottom)
        {
            targetTop = workArea.Bottom - targetSize.Height;
        }

        targetLeft = Math.Max(workArea.Left, targetLeft);
        targetTop = Math.Max(workArea.Top, targetTop);

        return new Point(targetLeft, targetTop);
    }
}
