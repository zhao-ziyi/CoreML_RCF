//
//  ViewController.swift
//  CoreMLDemo
//
//  Created by 赵子一 on 2022/8/31.
//

import UIKit
import Vision
import CoreImage
import SnapKit
import CoreML

class ViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate,UICollectionViewDelegate,UICollectionViewDataSource{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return predictions.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if model != nil{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellID", for: indexPath)
            let imageView = UIImageView(image: UIImage(ciImage: predictions[indexPath.row]))
            cell.contentView.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            return cell
        }
        else{
            return UICollectionViewCell()
        }
    }
    
    let inputImage = UIImageView()
    let maskImage = UIImageView()
    let outputImage = UIImageView()
    let netImage = UIImageView()
    var netImages:UICollectionView! = nil
    let load = UIActivityIndicatorView(style: .large)
    var model :bsds500_coreml!
    var predictions:[CIImage] = []
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        load.startAnimating()
        var image = info[UIImagePickerController.InfoKey(rawValue: "UIImagePickerControllerOriginalImage") ] as! UIImage
        self.inputImage.image = image
        Task{
            if image.imageOrientation == .right{
                image = image.rotate(radians: 0)!
            }
            
            let image2 = CIImage(image: image)!
            let mask =  await runSegmentation(input: image2)
            let mix = await runMask(foreground: image2, mask: mask)
            await runNet(inputImage: mix)
            setImage(mask: mask, mix: mix)
        }
        return
    }
    
    func setImage(mask:CIImage,mix:CIImage){
        self.maskImage.image = UIImage(ciImage: mask)
        self.outputImage.image = UIImage(ciImage: mix)
        netImages.reloadData()
        load.stopAnimating()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.addSubview(load)
        load.hidesWhenStopped = true
        load.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
        }
        load.startAnimating()
        Task{
            model = await loadModel()
            load.stopAnimating()
            print("model loaded")
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(showCamera))
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "photo"), style: .plain, target: self, action: #selector(openLibrary))
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = .systemBackground
        
        inputImage.contentMode = .scaleAspectFit
        self.view.addSubview(inputImage)
        inputImage.snp.makeConstraints { make in
            make.top.left.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.centerY)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.centerX)
        }
        outputImage.contentMode = .scaleAspectFit
        self.view.addSubview(outputImage)
        outputImage.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.centerY)
            make.top.right.equalTo(view.safeAreaLayoutGuide)
            make.left.equalTo(view.safeAreaLayoutGuide.snp.centerX)
        }
        
        let netImagesFlow = UICollectionViewFlowLayout()
        netImagesFlow.scrollDirection = .horizontal
        netImagesFlow.itemSize = CGSize(width: 150, height: 150)
        netImages = UICollectionView(frame: CGRect.zero, collectionViewLayout: netImagesFlow)
        netImages.delegate = self
        netImages.dataSource = self
        netImages.isScrollEnabled = true
        netImages.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cellID")
        self.view.addSubview(netImages)
        netImages.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.centerY)
            make.left.right.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        
        
        
//        let filters = CIFilter.filterNames(inCategory: kCICategoryBuiltIn)
//        print(filters)
    }
    @objc func showCamera(){
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                return
            }
            
            let cameraPicker = UIImagePickerController()
            cameraPicker.delegate = self
            cameraPicker.sourceType = .camera
            cameraPicker.allowsEditing = false
            present(cameraPicker, animated: true)
    }
    @objc func openLibrary(){
        let picker = UIImagePickerController()
            picker.allowsEditing = false
            picker.delegate = self
            picker.sourceType = .photoLibrary
            present(picker, animated: true)
    }
    
    func loadModel() async -> bsds500_coreml{
        return try!bsds500_coreml(configuration: MLModelConfiguration())
    }
    
    func runAll() async{
        
    }
    
    func runSegmentation(input:CIImage) async-> CIImage {
        let filter = CIFilter(name: "CIPersonSegmentation")!
        
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue("accurate", forKey: "inputQualityLevel")
        if let maskImage = filter.outputImage{

            let maskScaleX = input.extent.width / maskImage.extent.width
            let maskScaleY = input.extent.height / maskImage.extent.height

            let maskScaled =  maskImage.transformed(by: CGAffineTransform(scaleX: maskScaleX, y: maskScaleY))
            return maskScaled
        }
        return CIImage()
    }
    func runMask(foreground:CIImage,mask:CIImage)async->CIImage{
        let blendFilter = CIFilter(name: "CIBlendWithRedMask")!
        blendFilter.setValue(foreground, forKey: kCIInputImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        guard let masked = blendFilter.outputImage else{
            return CIImage()
        }
        let whiteBackground = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1))
        let whiteBackgroundScaled = whiteBackground.cropped(to: CGRect(x: 0, y: 0, width: masked.extent.width, height: masked.extent.height))
        let backgroundFilter = CIFilter(name: "CISourceOverCompositing")!
        backgroundFilter.setValue(masked, forKey: "inputImage")
        backgroundFilter.setValue(whiteBackgroundScaled, forKey: "inputBackgroundImage")
        return backgroundFilter.outputImage!
    }
    func runNet(inputImage:CIImage)async{
        
        let image = UIImage(ciImage: inputImage)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1024, height: 1024), true, 2.0)
        image.draw(in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) //3
        
        context?.translateBy(x: 0, y: newImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        guard let prediction = try? model.prediction(x: pixelBuffer!) else {
            return
        }
        predictions = []
        
        var result = prediction.var_651.ciImage(min: 0, max: 1, channel: nil, axes: (1,2,3))!
        
        let invertFilter = CIFilter(name: "CIColorInvert")!
        invertFilter.setValue(result, forKey: "inputImage")
        predictions.append(invertFilter.outputImage!)
        
        result = prediction.var_652.ciImage(min: 0, max: 1, channel: nil, axes: (1,2,3))!
        invertFilter.setValue(result, forKey: "inputImage")
        predictions.append(invertFilter.outputImage!)
        result = prediction.var_653.ciImage(min: 0, max: 1, channel: nil, axes: (1,2,3))!
        invertFilter.setValue(result, forKey: "inputImage")
        predictions.append(invertFilter.outputImage!)
        result = prediction.var_654.ciImage(min: 0, max: 1, channel: nil, axes: (1,2,3))!
        invertFilter.setValue(result, forKey: "inputImage")
        predictions.append(invertFilter.outputImage!)
        result = prediction.var_655.ciImage(min: 0, max: 1, channel: nil, axes: (1,2,3))!
        invertFilter.setValue(result, forKey: "inputImage")
        predictions.append(invertFilter.outputImage!)
        result = prediction.var_656.ciImage(min: 0, max: 1, channel: nil, axes: (1,2,3))!
        invertFilter.setValue(result, forKey: "inputImage")
        predictions.append(invertFilter.outputImage!)
    }
}

extension UIImage {
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}

extension UIImage {
    func scalePreservingAspectRatio(targetSize: CGSize) -> UIImage {
        // Determine the scale factor that preserves aspect ratio
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        
        // Compute the new image size that preserves aspect ratio
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        // Draw and return the resized UIImage
        let renderer = UIGraphicsImageRenderer(
            size: scaledImageSize
        )

        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(
                origin: .zero,
                size: scaledImageSize
            ))
        }
        
        return scaledImage
    }
}
