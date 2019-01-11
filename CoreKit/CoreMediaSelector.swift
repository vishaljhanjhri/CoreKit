//
//  CoreMediaSelector.swift
//  CoreKit
//
//  Created by Vishal on 09/01/19.
//  Copyright © 2019 Vishal. All rights reserved.
//

import UIKit
import MediaPlayer
import MobileCoreServices
import AVFoundation

public enum SelectImageError: LocalizedError {
    case cameraNotFound
    case photoLibraryNotFound
    case unsupportedFileType
    
    public var errorDescription: String? {
        switch self {
        case .cameraNotFound:
            return "Camera not found in this device."
        case .photoLibraryNotFound:
            return "Photo library is not available"
        case .unsupportedFileType:
            return "File Type is not supported"
        }
    }
}

public protocol CoreMediaSelectorDelegate: class {
    func imageViewPickerDidFinish(mediaSelector: CoreMediaSelector, with result: CoreMediaSelector.Result)
    func imagePickingError(mediaSelector: CoreMediaSelector, error: Error)
}


public class CoreMediaSelector: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    public struct Result {
        public let isSuccessful: Bool
        public let error: Error?
        public let info: [UIImagePickerController.InfoKey : Any]?
        public let filePath: String?
        public let mediaType: MediaType?
        public let soucreType: UIImagePickerController.SourceType?
        public let image: UIImage?
        
        
        public enum MediaType {
            case imageType
            case gifType
            case movieType
            
            
            func getExtension() -> String {
                switch  self {
                case .gifType:
                    return ".gif"
                default:
                    return ".jpg"
                }
            }
        }
    }
    
    public enum FileType {
        case video
        case image
    }
    
    // MARK: - Properties
    private var filePath = String()
    private var fileName: String = ""
    public weak var delegate: CoreMediaSelectorDelegate?
    
    // MARK: - Intializer
    public init(delegate: CoreMediaSelectorDelegate) {
        self.delegate = delegate
    }
    
    // MARK: - Methods
    public func selectImage(viewController: UIViewController, fileName: String, fileTypes: [FileType]) {
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        let cameraTitle = "Open Camera"
        
        let cameraAction = UIAlertAction(title: cameraTitle, style: .default, handler: {
            [weak self] (alert: UIAlertAction!) -> Void in
            self?.openCameraFor(fileName: fileName, fileTypes: fileTypes, inViewController: viewController)
        })
        
        let photoLibraryAction = UIAlertAction(title: "Choose from existing", style: .default, handler: { [weak self]
            (alert: UIAlertAction!) -> Void in
            self?.openPhotoLibraryFor(fileName: fileName, fileTypes: fileTypes, inViewController: viewController)
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (alert: UIAlertAction!) -> Void in
        })
        
        actionSheet.addAction(cameraAction)
        actionSheet.addAction(photoLibraryAction)
        actionSheet.addAction(cancelAction)
        
        actionSheet.popoverPresentationController?.sourceRect = viewController.view?.bounds ?? CGRect.zero
        actionSheet.popoverPresentationController?.sourceView = viewController.view
        
        if #available(iOS 9.0, *) {
            actionSheet.popoverPresentationController?.canOverlapSourceViewRect = true
        }
        
        viewController.present(actionSheet, animated: true, completion: nil)
    }
    
    public func openCameraFor(fileName: String, fileTypes: [FileType], inViewController vc: UIViewController) {
        self.fileName = fileName
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
            let picker = getImagePicker()
            setPickerForCamera(picker: picker, forFileType: fileTypes)
            vc.present(picker, animated: true, completion: nil)
        } else {
            let result = Result(isSuccessful: false, error: SelectImageError.cameraNotFound, info: nil, filePath: nil, mediaType: nil, soucreType: .camera, image: nil)
            self.delegate?.imageViewPickerDidFinish(mediaSelector: self, with: result)
        }
    }
    
    public func openPhotoLibraryFor(fileName: String, fileTypes: [FileType], inViewController vc: UIViewController) {
        self.fileName = fileName
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let picker = getImagePicker()
            self.setPickerForPhotoLibrary(picker: picker, forFileType: fileTypes)
            vc.present(picker, animated: true, completion: nil)
        } else {
            let result = Result(isSuccessful: false, error: SelectImageError.photoLibraryNotFound, info: nil, filePath: nil, mediaType: nil, soucreType: .photoLibrary, image: nil)
            self.delegate?.imageViewPickerDidFinish(mediaSelector: self, with: result)
        }
        
    }
    
    private func getImagePicker() -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        return imagePicker
    }
    
    private func setFilePathWith(fileName: String, mediaType: Result.MediaType) {
        filePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0].appendingFormat("/\(fileName)\(mediaType.getExtension())")
    }
    
    private func setPickerForCamera(picker: UIImagePickerController, forFileType fileTypes: [FileType]) {
        picker.sourceType = UIImagePickerController.SourceType.camera
        
        var allowedTypes: [String] = []
        
        if fileTypes.contains(.image) {
            allowedTypes.append(kUTTypeImage as String)
        }
        
        if fileTypes.contains(.video) {
            let videoType = [kUTTypeMovie as String, kUTTypeGIF as String]
            allowedTypes.append(contentsOf: videoType)
        }
        picker.videoMaximumDuration = 20.0
        picker.mediaTypes = allowedTypes
        picker.delegate = self
    }
    
    private func setPickerForPhotoLibrary(picker: UIImagePickerController, forFileType fileTypes: [FileType]) {
        picker.sourceType = UIImagePickerController.SourceType.photoLibrary
        
        var allowedTypes: [String] = []
        
        if fileTypes.contains(.image) {
            allowedTypes.append(kUTTypeImage as String)
            allowedTypes.append(kUTTypeGIF as String)
            allowedTypes.append("public.image")
        }
        
        if fileTypes.contains(.video) {
            let videoType = [kUTTypeMovie as String, ]
            allowedTypes.append(contentsOf: videoType)
        }
        picker.mediaTypes = allowedTypes
        picker.delegate = self
    }
    
    //MARK: --
    
    
    private func compressImage(originalImage: UIImage) -> (UIImage?, Error?) {
        guard CoreKit.shared.filesConfig.enableResizingImage else {
            return (originalImage, nil)
        }
        let size = originalImage.jpegData(compressionQuality: 1.0)!.count
        
        if size > 2048 {
            do {
                try originalImage.jpegData(compressionQuality: 0.05)?.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            } catch {
               return (originalImage, error)
            }
        } else {
            do {
                try originalImage.jpegData(compressionQuality: 0.55)?.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            }catch {
                return (originalImage, error)
            }
        }
        return (originalImage, nil)
    }
    private func rotateAndCompressImageIfRequired(originalImage: UIImage) -> UIImage? {
        var workingImage = originalImage
        
        if CoreKit.shared.filesConfig.rotateImageIfRequired {
            let resolution = CoreKit.shared.filesConfig.maxResolution
            workingImage = workingImage.rotateCameraImageToProperOrientation(maxResolution: resolution)
        }
        
        let imageInfoWithError = compressImage(originalImage: workingImage)
        
        if let error = imageInfoWithError.1 {
            let result = Result(isSuccessful: false, error: error, info: nil, filePath: nil, mediaType: nil, soucreType: .camera, image: nil)
            self.delegate?.imageViewPickerDidFinish(mediaSelector: self, with: result)
        }
        return imageInfoWithError.0
    }
    // MARK: Image Picker Delegates
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String else {
            return
        }
        
        let imageType = kUTTypeImage as String
        let gifType = kUTTypeGIF as String
        let movieType = kUTTypeMovie as String
        
        var result: Result?
        
        switch mediaType {
        case imageType, gifType:
            guard let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
                picker.dismiss(animated: true, completion: nil)
                return
            }
            let type = mediaType == gifType ? Result.MediaType.gifType : Result.MediaType.imageType
            setFilePathWith(fileName: self.fileName, mediaType: type)
            
            guard let formattedImage = rotateAndCompressImageIfRequired(originalImage: pickedImage) else {
                picker.dismiss(animated: true, completion: nil)
                return
            }
            result = Result(isSuccessful: true, error: nil, info: info, filePath: filePath, mediaType: type, soucreType: picker.sourceType, image: formattedImage)
            
        case movieType:
            guard let parsedUrl = info[UIImagePickerController.InfoKey.mediaURL] as? URL else {
                picker.dismiss(animated: true, completion: nil)
                return
            }
            guard CoreKit.shared.filesConfig.checkForDataSelectionLimit(url: parsedUrl) == true else {
                picker.dismiss(animated: true, completion: nil)
                return
            }
            let type = Result.MediaType.movieType
            result = Result(isSuccessful: true, error: nil, info: info, filePath: parsedUrl.path, mediaType: type, soucreType: picker.sourceType, image: nil)
            
        default:
            result = Result(isSuccessful: false, error: SelectImageError.unsupportedFileType, info: nil, filePath: nil, mediaType: nil, soucreType: picker.sourceType, image: nil)
        }
        picker.dismiss(animated: true) {
            self.delegate?.imageViewPickerDidFinish(mediaSelector: self, with: result!)
        }
        
    }
    
    private func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
}
