/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

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

import UIKit
import Chatto

public protocol TextBubbleViewStyleProtocol {
    func bubbleImage(viewModel: TextMessageViewModelProtocol, isSelected: Bool) -> UIImage
    func bubbleImageBorder(viewModel: TextMessageViewModelProtocol, isSelected: Bool) -> UIImage?
    func textFont(viewModel: TextMessageViewModelProtocol, isSelected: Bool) -> UIFont
    func textColor(viewModel: TextMessageViewModelProtocol, isSelected: Bool) -> UIColor
    func textInsets(viewModel: TextMessageViewModelProtocol, isSelected: Bool) -> UIEdgeInsets
}

public final class TextBubbleView: UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {

    public var preferredMaxLayoutWidth: CGFloat = 0
    public var animationDuration: CFTimeInterval = 0.33
    public var viewContext: ViewContext = .normal {
        didSet {
            if self.viewContext == .sizing {
                self.textView.dataDetectorTypes = UIDataDetectorTypes()
//                self.textView.isSelectable = false
            } else {
                self.textView.dataDetectorTypes = .all
//                self.textView.isSelectable = true
            }
        }
    }

    public var style: TextBubbleViewStyleProtocol! {
        didSet {
            self.updateViews()
        }
    }

    public var textMessageViewModel: TextMessageViewModelProtocol! {
        didSet {
            self.updateViews()
        }
    }

    public var selected: Bool = false {
        didSet {
            if self.selected != oldValue {
                self.updateViews()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    private func commonInit() {
        self.addSubview(self.bubbleImageView)
        self.addSubview(self.textView)
    }

    private lazy var bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.addSubview(self.borderImageView)
        return imageView
    }()

    private var borderImageView: UIImageView = UIImageView()
    private var textView: UITextView = {
        let textView = ChatMessageTextView()
        UIView.performWithoutAnimation({ () -> Void in // fixes iOS 8 blinking when cell appears
            textView.backgroundColor = UIColor.clear
        })
        textView.isEditable = false
        textView.isSelectable = false
        textView.dataDetectorTypes = .all
        textView.scrollsToTop = false
        textView.isScrollEnabled = false
        textView.bounces = false
        textView.bouncesZoom = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.isExclusiveTouch = true
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }()

    public private(set) var isUpdating: Bool = false
    public func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        self.isUpdating = true
        let updateAndRefreshViews = {
            updateClosure()
            self.isUpdating = false
            self.updateViews()
            if animated {
                self.layoutIfNeeded()
            }
        }
        if animated {
            UIView.animate(withDuration: self.animationDuration, animations: updateAndRefreshViews, completion: { (_) -> Void in
                completion?()
            })
        } else {
            updateAndRefreshViews()
        }
    }

    private func updateViews() {
        if self.viewContext == .sizing { return }
        if isUpdating { return }
        guard let style = self.style else { return }

        self.updateTextView()
        let bubbleImage = style.bubbleImage(viewModel: self.textMessageViewModel, isSelected: self.selected)
        let borderImage = style.bubbleImageBorder(viewModel: self.textMessageViewModel, isSelected: self.selected)
        if self.bubbleImageView.image != bubbleImage { self.bubbleImageView.image = bubbleImage }
        if self.borderImageView.image != borderImage { self.borderImageView.image = borderImage }
    }

    private func updateTextView() {
        guard let style = self.style, let viewModel = self.textMessageViewModel else { return }

        let font = style.textFont(viewModel: viewModel, isSelected: self.selected)
        let textColor = style.textColor(viewModel: viewModel, isSelected: self.selected)

        var needsToUpdateText = false

        if self.textView.font != font {
            self.textView.font = font
            needsToUpdateText = true
        }

        if self.textView.textColor != textColor {
            self.textView.textColor = textColor
            self.textView.linkTextAttributes = [
                NSForegroundColorAttributeName: textColor,
                NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue
            ]
            needsToUpdateText = true
        }

        if needsToUpdateText || self.textView.text != viewModel.text {            
            let formattedText = formatString(viewModel.text)
            self.textView.attributedText = formattedText
        }

        let textInsets = style.textInsets(viewModel: viewModel, isSelected: self.selected)
        if self.textView.textContainerInset != textInsets { self.textView.textContainerInset = textInsets }
    }

    private func bubbleImage() -> UIImage {
        return self.style.bubbleImage(viewModel: self.textMessageViewModel, isSelected: self.selected)
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateTextBubbleLayout(preferredMaxLayoutWidth: size.width).size
    }

    // MARK: Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        let layout = self.calculateTextBubbleLayout(preferredMaxLayoutWidth: self.preferredMaxLayoutWidth)
        self.textView.bma_rect = layout.textFrame
        self.bubbleImageView.bma_rect = layout.bubbleFrame
        self.borderImageView.bma_rect = self.bubbleImageView.bounds
    }

    public var layoutCache: NSCache<AnyObject, AnyObject>!
    private func calculateTextBubbleLayout(preferredMaxLayoutWidth: CGFloat) -> TextBubbleLayoutModel {
        let layoutContext = TextBubbleLayoutModel.LayoutContext(
            text: self.textMessageViewModel.text,
            font: self.style.textFont(viewModel: self.textMessageViewModel, isSelected: self.selected),
            textInsets: self.style.textInsets(viewModel: self.textMessageViewModel, isSelected: self.selected),
            preferredMaxLayoutWidth: preferredMaxLayoutWidth
        )

        if let layoutModel = self.layoutCache.object(forKey: layoutContext.hashValue as AnyObject) as? TextBubbleLayoutModel, layoutModel.layoutContext == layoutContext {
            return layoutModel
        }

        let layoutModel = TextBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()

        self.layoutCache.setObject(layoutModel, forKey: layoutContext.hashValue as AnyObject)
        return layoutModel
    }

    public var canCalculateSizeInBackground: Bool {
        return true
    }
}

private final class TextBubbleLayoutModel {
    let layoutContext: LayoutContext
    var textFrame: CGRect = CGRect.zero
    var bubbleFrame: CGRect = CGRect.zero
    var size: CGSize = CGSize.zero

    init(layoutContext: LayoutContext) {
        self.layoutContext = layoutContext
    }

    struct LayoutContext: Equatable, Hashable {
        let text: String
        let font: UIFont
        let textInsets: UIEdgeInsets
        let preferredMaxLayoutWidth: CGFloat

        var hashValue: Int {
            return Chatto.bma_combine(hashes: [self.text.hashValue, self.textInsets.bma_hashValue, self.preferredMaxLayoutWidth.hashValue, self.font.hashValue])
        }

        static func == (lhs: TextBubbleLayoutModel.LayoutContext, rhs: TextBubbleLayoutModel.LayoutContext) -> Bool {
            let lhsValues = (lhs.text, lhs.textInsets, lhs.font, lhs.preferredMaxLayoutWidth)
            let rhsValues = (rhs.text, rhs.textInsets, rhs.font, rhs.preferredMaxLayoutWidth)
            return lhsValues == rhsValues
        }
    }

    func calculateLayout() {
        let textHorizontalInset = self.layoutContext.textInsets.bma_horziontalInset
        let maxTextWidth = self.layoutContext.preferredMaxLayoutWidth - textHorizontalInset
        let textSize = self.textSizeThatFitsWidth(maxTextWidth)
        let bubbleSize = textSize.bma_outsetBy(dx: textHorizontalInset, dy: self.layoutContext.textInsets.bma_verticalInset)
        self.bubbleFrame = CGRect(origin: CGPoint.zero, size: bubbleSize)
        self.textFrame = self.bubbleFrame
        self.size = bubbleSize
    }

    private func textSizeThatFitsWidth(_ width: CGFloat) -> CGSize {
        let textContainer: NSTextContainer = {
            let size = CGSize(width: width, height: .greatestFiniteMagnitude)
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            return container
        }()

        let textStorage = self.replicateUITextViewNSTextStorage()
        let layoutManager: NSLayoutManager = {
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            return layoutManager
        }()

        let rect = layoutManager.usedRect(for: textContainer)
        return rect.size.bma_round()
    }

    private func replicateUITextViewNSTextStorage() -> NSTextStorage {
        // See https://github.com/badoo/Chatto/issues/129
        return NSTextStorage(string: self.layoutContext.text, attributes: [
            NSFontAttributeName: self.layoutContext.font,
            "NSOriginalFont": self.layoutContext.font
        ])
    }
}

/// UITextView with hacks to avoid selection, loupe, define...
private final class ChatMessageTextView: UITextView {

    override var canBecomeFirstResponder: Bool {
        return false
    }

    override func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if type(of: gestureRecognizer) == UILongPressGestureRecognizer.self && gestureRecognizer.delaysTouchesEnded {
            super.addGestureRecognizer(gestureRecognizer)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }

    override var selectedRange: NSRange {
        get {
            return NSRange(location: 0, length: 0)
        }
        set {
            // Part of the heaviest stack trace when scrolling (when updating text)
            // See https://github.com/badoo/Chatto/pull/144
        }
    }

    override var contentOffset: CGPoint {
        get {
            return .zero
        }
        set {
            // Part of the heaviest stack trace when scrolling (when bounds are set)
            // See https://github.com/badoo/Chatto/pull/144
        }
    }
}

extension TextBubbleView {
    func formatString(_ str : String) -> NSAttributedString {
        
        let fontSize: CGFloat = 15
        
        let boldMarker = "*"
        let italicMarker = "_"
        let strikethroughMarker = "~"
        let underlineMarker = "```"
        
        var textsToReplace = [(String, String)]()
        
        let boldRegEx = try! NSRegularExpression(pattern: "[*][^[*]]*?[*]", options: NSRegularExpression.Options.caseInsensitive)
        let italicRegEx = try! NSRegularExpression(pattern: "_[^_]*?_", options: NSRegularExpression.Options.caseInsensitive)
        let strikethroughRegEx = try! NSRegularExpression(pattern: "~[^~]*?~", options: NSRegularExpression.Options.caseInsensitive)
        let underlineRegEx = try! NSRegularExpression(pattern: "```[^```]*?```", options: NSRegularExpression.Options.caseInsensitive)
        
        let formattedString = NSMutableAttributedString(string: str)
        
        let boldMatches = boldRegEx.matches(in: str, options: [], range: NSMakeRange(0, str.characters.count))
        let italicMatches = italicRegEx.matches(in: str, options: [], range: NSMakeRange(0, str.characters.count))
        let strikethroughMatches = strikethroughRegEx.matches(in: str, options: [], range: NSMakeRange(0, str.characters.count))
        let underlineMatches = underlineRegEx.matches(in: str, options: [], range: NSMakeRange(0, str.characters.count))
        
        formattedString.addAttribute(NSFontAttributeName, value: UIFont.systemFont(ofSize: fontSize), range: NSMakeRange(0, formattedString.string.characters.count))
        
        for match in boldMatches {
            
            formattedString.addAttribute(NSFontAttributeName, value: UIFont.boldSystemFont(ofSize: fontSize), range: match.range)
            
            let startIndex = str.index(str.startIndex, offsetBy: match.range.location)
            let endIndex = str.index(str.startIndex, offsetBy: match.range.length + match.range.location-1)
            
            let originalText = str[startIndex...endIndex]
            let targetText = originalText.replacingOccurrences(of: boldMarker, with: "")
            
            textsToReplace.append((originalText, targetText))
        }
        
        for match in italicMatches {
            
            formattedString.addAttribute(NSFontAttributeName, value: UIFont.italicSystemFont(ofSize: fontSize), range: match.range)
            
            let startIndex = str.index(str.startIndex, offsetBy: match.range.location)
            let endIndex = str.index(str.startIndex, offsetBy: match.range.length + match.range.location-1)
            
            let originalText = str[startIndex...endIndex]
            let targetText = originalText.replacingOccurrences(of: italicMarker, with: "")
            
            textsToReplace.append((originalText, targetText))
            
        }
        
        for match in strikethroughMatches {
            formattedString.addAttribute(NSBaselineOffsetAttributeName, value: 0, range: match.range)
            formattedString.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: match.range)
            
            let startIndex = str.index(str.startIndex, offsetBy: match.range.location)
            let endIndex = str.index(str.startIndex, offsetBy: match.range.length + match.range.location-1)
            
            let originalText = str[startIndex...endIndex]
            let targetText = originalText.replacingOccurrences(of: strikethroughMarker, with: "")
            
            textsToReplace.append((originalText, targetText))
            
        }
        
        for match in underlineMatches {
            formattedString.addAttribute(NSUnderlineStyleAttributeName, value: NSUnderlineStyle.styleSingle.rawValue, range: match.range)
            
            let startIndex = str.index(str.startIndex, offsetBy: match.range.location)
            let endIndex = str.index(str.startIndex, offsetBy: match.range.length + match.range.location-1)
            
            let originalText = str[startIndex...endIndex]
            let targetText = originalText.replacingOccurrences(of: underlineMarker, with: "")
            
            textsToReplace.append((originalText, targetText))
            
        }
        
        for (oldString, newString) in textsToReplace {
            formattedString.mutableString.replaceOccurrences(of: oldString, with: newString, options: [], range: NSMakeRange(0, formattedString.string.characters.count))
        }
        
        return formattedString
    }
}
