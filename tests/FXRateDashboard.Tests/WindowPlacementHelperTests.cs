using System.Windows;
using FXRateDashboard.Utilities;

namespace FXRateDashboard.Tests;

public sealed class WindowPlacementHelperTests
{
    [Fact]
    public void CalculateClampedTopLeft_ShiftsLeftWhenExpansionWouldOverflowRightEdge()
    {
        var result = WindowPlacementHelper.CalculateClampedTopLeft(
            new Rect(0, 0, 1920, 1080),
            new Rect(1600, 40, 196, 122),
            new Size(404, 410));

        Assert.Equal(1516, result.X);
        Assert.Equal(40, result.Y);
    }

    [Fact]
    public void CalculateClampedTopLeft_AnchorsToRightEdgeWhenWidgetIsDockedRight()
    {
        var result = WindowPlacementHelper.CalculateClampedTopLeft(
            new Rect(0, 0, 1920, 1080),
            new Rect(1684, 40, 236, 122),
            new Size(404, 410));

        Assert.Equal(1516, result.X);
        Assert.Equal(40, result.Y);
    }

    [Fact]
    public void CalculateClampedTopLeft_ShiftsUpWhenExpansionWouldOverflowBottomEdge()
    {
        var result = WindowPlacementHelper.CalculateClampedTopLeft(
            new Rect(0, 0, 1920, 1080),
            new Rect(1200, 900, 196, 122),
            new Size(404, 410));

        Assert.Equal(1200, result.X);
        Assert.Equal(670, result.Y);
    }

    [Fact]
    public void CalculateClampedTopLeft_AnchorsToBottomEdgeWhenWidgetIsDockedBottom()
    {
        var result = WindowPlacementHelper.CalculateClampedTopLeft(
            new Rect(0, 0, 1920, 1080),
            new Rect(1200, 958, 236, 122),
            new Size(404, 410));

        Assert.Equal(1200, result.X);
        Assert.Equal(670, result.Y);
    }
}
