import UIKit

/// SignatureScrollView allows the user to draw on child SignatureDrawingViews without the parent ScrollView
///     intercepting touches.
/// Normally, a ScrollView will intercept any touch to the screen to determine if it is a scroll or not.
///     If the user tries to draw, the ScrollView will think the user is trying to scroll, and thus intercept the
///     drawing.
/// This class does not intercept any touches that touch inside a SignatureDrawingView, and thus will allow
///     the correct drawing behaviour to occur.
class SignatureScrollView: UIScrollView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        // This is needed as the ScrollView intercept usually happens after a small delay, this makes the intercept
        //      happen immediately, which we can then reject immediately to draw.
        delaysContentTouches = false
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        if view is SignatureDrawingView {
            return false
        }

        return true
    }

}
