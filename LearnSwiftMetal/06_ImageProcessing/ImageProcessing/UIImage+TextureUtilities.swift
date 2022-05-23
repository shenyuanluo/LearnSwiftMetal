//
//  UIImage+TextureUtilities.swift
//  06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/18.
//

import UIKit

extension UIImage {
    // MAKR: 纹理转图片
    class func imageWith(texture: MTLTexture) -> UIImage? {
        let imageSize      = CGSize(width: texture.width, height: texture.height)
        let bytesPerPixel  = 4
        let imageByteCount = imageSize.width * imageSize.height * CGFloat(bytesPerPixel)
        let imageData      = UnsafeMutableRawPointer.allocate(byteCount: Int(imageByteCount), alignment: 8)
        let bytesPerRow    = Int(imageSize.width) * bytesPerPixel
        let region         = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                       size: MTLSize(width: Int(imageSize.width), height: Int(imageSize.height), depth: 1))
        
        texture.getBytes(imageData, bytesPerRow: Int(bytesPerRow), from: region, mipmapLevel: 0)
        
        let bitsPerComponent = 8
        let bitsPerPixel     = bitsPerComponent * bytesPerPixel
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo       = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        let provider         = CGDataProvider(dataInfo: nil,
                                              data: imageData,
                                              size: Int(imageByteCount)) {
            info, data, size in
            free(UnsafeMutableRawPointer(mutating: data))   // 这里需要释放，否则会内存泄漏
        }
        if let provider = provider {
            let cgImage = CGImage(width: Int(imageSize.width),
                                  height: Int(imageSize.height),
                                  bitsPerComponent: bitsPerComponent,
                                  bitsPerPixel: bitsPerPixel,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo,
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent)
            if let cgImage = cgImage {
                let image = UIImage(cgImage: cgImage)
                return image
            }
        }
        
        return nil
    }
}
