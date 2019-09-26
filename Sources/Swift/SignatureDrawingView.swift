/**
 Copyright (c) 2017 Uber Technologies, Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

/*
 This library is originally from https://github.com/uber/UberSignature

 Small modifications has been made on top of commit: 2bb915e879aeab343993baa6250ad3d54485f673
 1. update line 65 in file UIBezierPath+WeightedPoint.swift.
 change it from `path.addLine(to: lines.0.start)` to `path.addLine(to: lines.0.end)`
 As it was mentioned in one of the issue: https://github.com/uber/UberSignature/issues/16
 This update fixes the issue that lines have unexpected triangles in the end as mentioned in another issue: https://github.com/uber/UberSignature/issues/7

 2. Add class `SignatureDrawingView` to replace `SignatureDrawingViewController`. 99% of the code in `SignatureDrawingView` is copied from `SignatureDrawingViewController`. The only difference is it's changed from a `UIViewController` subclass to `UIView` subclass. The auto layout constraints has also been updated to take safeArea into account.
 */

import UIKit

public protocol SignatureDrawingViewDelegate: class {
    /// Callback when isEmpty changes, due to user drawing or reset() being called.
    func signatureDrawingViewIsEmptyDidChange(view: SignatureDrawingView, isEmpty: Bool)
}

// Use this view as is, and add it to wherever you like. After user draws signature, you can call fullSignatureImage() to get an image of the signature with transparent background.
public class SignatureDrawingView: UIView {

    // MARK: - Private Properties

    private let model = SignatureDrawingModelAsync()
    private lazy var bezierPathLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = signatureColor.cgColor
        layer.fillColor = signatureColor.cgColor

        return layer
    }()
    private var imageView = UIImageView()
    
    // MARK: - Public Properties

    /**
     The color of the signature.
     Defaults to black.
     */
    public var signatureColor: UIColor {
        get {
            return model.signatureColor
        }
        set(color) {
            model.signatureColor = color
            bezierPathLayer.strokeColor = color.cgColor
            bezierPathLayer.fillColor = color.cgColor
        }
    }

    /**
     Whether the signature drawing is empty or not.
     This changes when the user draws or the view is reset.
     - note: Defaults to false if there's a starting image.
     */
    private(set) var isEmpty = true {
        didSet {
            if isEmpty != oldValue {
                delegate?.signatureDrawingViewIsEmptyDidChange(view: self, isEmpty: isEmpty)
            }
        }
    }

    /// Delegate for callbacks.
    public weak var delegate: SignatureDrawingViewDelegate?

    // MARK: - Life Cycle
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = UIColor.clear
        clipsToBounds = true
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
            ])
        layer.addSublayer(bezierPathLayer)
    }

    public override func layoutSubviews() {
        // Any frame change after something has been drawn to canvas cause the canvas to reset image.
        let cachedImage = model.fullSignatureImage
        super.layoutSubviews()
        model.imageSize = bounds.size
        if let image = cachedImage {
            model.reset()
            model.addImageToSignature(image)
        }
        updateViewFromModel()
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        updateModel(withTouches: touches, shouldEndContinousLine: true)
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        updateModel(withTouches: touches, shouldEndContinousLine: false)
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        model.asyncEndContinuousLine()
    }

    // MARK: - Public Methods
    
    /// Returns an image of the signature (with a transparent background).
    public func fullSignatureImage() -> UIImage? {
        return model.fullSignatureImage
    }

    /// Resets the signature.
    public func reset() {
        model.reset()
        updateViewFromModel()
    }

    /// You can add existing images to the signature canvas.
    ///
    /// - It will overlap with existing graphic in canvas. If you want to replace current graphic in canvas, you can call `reset()` first before calling this method.
    /// - This method should be called after the view's frame has been finalised.
    /// - the image added will be scaled with aspectFit mode.
    ///
    /// - Parameter image: The image you want to add to canvas
    public func addImageToSignature(_ image: UIImage) {
        model.addImageToSignature(image)
        updateViewFromModel()
    }

    // MARK: - Private Methods

    private func updateModel(withTouches touches: Set<UITouch>, shouldEndContinousLine: Bool) {
        guard let touchPoint = touches.touchPoint else {
            return
        }

        if shouldEndContinousLine {
            model.asyncEndContinuousLine()
        }
        model.asyncUpdate(withPoint: touchPoint)
        updateViewFromModel()
    }

    private func updateViewFromModel() {
        model.asyncGetOutput { (output) in
            if self.imageView.image != output.signatureImage {
                self.imageView.image = output.signatureImage
            }
            if self.bezierPathLayer.path != output.temporarySignatureBezierPath?.cgPath {
                self.bezierPathLayer.path = output.temporarySignatureBezierPath?.cgPath
            }

            self.isEmpty = self.bezierPathLayer.path == nil && self.imageView.image == nil
        }
    }
}

fileprivate extension Set where Element == UITouch {
    var touchPoint: CGPoint? {
        let touch = first

        return touch?.location(in: touch?.view)
    }
}
