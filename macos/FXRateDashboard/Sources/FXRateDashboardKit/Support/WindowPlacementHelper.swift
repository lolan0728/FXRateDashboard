import CoreGraphics

public enum WindowPlacementHelper {
    private static let edgeAnchorThreshold: CGFloat = 24

    public static func calculateClampedTopLeft(
        workArea: CGRect,
        currentBounds: CGRect,
        targetSize: CGSize
    ) -> CGPoint {
        let isAnchoredToRight = workArea.maxX - currentBounds.maxX <= edgeAnchorThreshold
        let isAnchoredToBottom = workArea.maxY - currentBounds.maxY <= edgeAnchorThreshold

        var targetLeft = isAnchoredToRight ? currentBounds.maxX - targetSize.width : currentBounds.minX
        var targetTop = isAnchoredToBottom ? currentBounds.maxY - targetSize.height : currentBounds.minY

        if targetLeft + targetSize.width > workArea.maxX {
            targetLeft = workArea.maxX - targetSize.width
        }

        if targetTop + targetSize.height > workArea.maxY {
            targetTop = workArea.maxY - targetSize.height
        }

        targetLeft = max(workArea.minX, targetLeft)
        targetTop = max(workArea.minY, targetTop)

        return CGPoint(x: targetLeft, y: targetTop)
    }
}
