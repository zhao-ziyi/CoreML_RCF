//
//  FixOrientation.swift
//  CoreMLDemo
//
//  Created by 赵子一 on 2022/9/1.
//

import Foundation
import UIKit
/**
     照片竖拍  web显示旋转解决:图片大于2M会自动旋转90度
      
     - parameter aImage: <#aImage description#>
      
     - returns: <#return value description#>
     */
func fixOrientation(aImage:UIImage)->UIImage  {
    if aImage.imageOrientation == UIImage.Orientation.up{
            return aImage
        }
     
    var transform = CGAffineTransform()
         
        switch (aImage.imageOrientation) {
        case .down,.downMirrored:
            transform = transform.translatedBy(x: aImage.size.width, y: aImage.size.height)
            transform = transform.rotated(by: CGFloat(Double.pi))
        break;
         
        case .left,.leftMirrored:
            transform = transform.translatedBy(x: aImage.size.width, y: 0)
            transform = transform.rotated(by: CGFloat(Double.pi/2))
        break;
         
        case .right,.rightMirrored:
            transform = transform.translatedBy(x: 0, y: aImage.size.height)
            transform = transform.rotated(by: CGFloat(-Double.pi/2))
        break;
        default:
        break;
        }
         
        switch (aImage.imageOrientation) {
        case .upMirrored,.downMirrored:
            transform = transform.translatedBy(x: aImage.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        break;
         
        case .leftMirrored,.rightMirrored:
            transform = transform.translatedBy(x: aImage.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        break;
        default:
        break;
        }
         
    let ctx:CGContext = CGContext(data: nil, width: Int(aImage.size.width), height: Int(aImage.size.height),
                                  bitsPerComponent: aImage.cgImage!.bitsPerComponent, bytesPerRow: 0,
                                  space: aImage.cgImage!.colorSpace!,
                                  bitmapInfo: 1)!
 
 
         
    ctx.concatenate(transform)
        switch (aImage.imageOrientation) {
        case .left,.leftMirrored,.right,.rightMirrored:
            ctx.draw(aImage.cgImage!, in: CGRect(x: 0,y: 0,width: aImage.size.height,height: aImage.size.width))
//            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.cgImage)
        break;
         
        default:
            ctx.draw(aImage.cgImage!, in: CGRect(x: 0,y: 0,width: aImage.size.width,height: aImage.size.height))
//            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.cgImage);
        break;
        }
         
    let cgimg:CGImage = ctx.makeImage()!
    let img:UIImage = UIImage(cgImage: cgimg)
        return img;
        }
