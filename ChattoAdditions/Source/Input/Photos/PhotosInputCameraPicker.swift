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
import MobileCoreServices

class PhotosInputCameraPicker: NSObject {
    weak var presentingController: UIViewController?
    init(presentingController: UIViewController?) {
        self.presentingController = presentingController
    }
    
    private var completionBlocks: (onImageTaken: ((UIImage?) -> Void)?, onVideoTaken: ((URL?) -> Void)?, onCameraPickerDismissed: (() -> Void)?)?
    
    func presentCameraPicker(onImageTaken: @escaping (UIImage?) -> Void, onVideoTaken: @escaping (URL?) -> Void, onCameraPickerDismissed: @escaping () -> Void) {
        
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            onImageTaken(nil)
            onVideoTaken(nil)
            onCameraPickerDismissed()
            return
        }
        
        guard let presentingController = self.presentingController else {
            onImageTaken(nil)
            onVideoTaken(nil)
            onCameraPickerDismissed()
            
            return
        }
        
        self.completionBlocks = (onImageTaken: onImageTaken, onVideoTaken: onVideoTaken, onCameraPickerDismissed: onCameraPickerDismissed)
        let controller = UIImagePickerController()
        controller.delegate = self
        controller.sourceType = .camera
        controller.mediaTypes = [kUTTypeMovie as String, kUTTypeImage as String]
        presentingController.present(controller, animated: true, completion:nil)
    }
    
    fileprivate func finishPickingImage(_ image: UIImage?, fromPicker picker: UIImagePickerController) {
        let (onImageTaken, onVideoTaken, onCameraPickerDismissed) = self.completionBlocks ?? (nil, nil, nil)
        picker.dismiss(animated: true, completion: onCameraPickerDismissed)
        onImageTaken?(image)
    }
    
    fileprivate func finishPickingVideo(_ videoUrl: URL?, fromPicker picker: UIImagePickerController) {
        let (onImageTaken, onVideoTaken, onCameraPickerDismissed) = self.completionBlocks ?? (nil, nil, nil)
        picker.dismiss(animated: true, completion: onCameraPickerDismissed)
        onVideoTaken?(videoUrl)
    }
}

extension PhotosInputCameraPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        let pickedMediaType = info[UIImagePickerControllerMediaType] as! CFString
        if pickedMediaType == kUTTypeImage {
            
            self.finishPickingImage(info[UIImagePickerControllerOriginalImage] as! UIImage, fromPicker: picker)
            
        } else if pickedMediaType == kUTTypeMovie {
            
            let videoURL = info[UIImagePickerControllerMediaURL] as! URL
            self.finishPickingVideo(videoURL, fromPicker: picker)
            
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.finishPickingImage(nil, fromPicker: picker)
    }
}

