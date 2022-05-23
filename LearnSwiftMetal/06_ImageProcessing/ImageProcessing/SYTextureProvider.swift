//
//  SYTextureProvider.swift
//  06_ImageProcessing
//
//  Created by ShenYuanLuo on 2022/5/17.
//

import Foundation
import Metal
import UIKit


/// 纹理提供协议
protocol SYTextureProviderProtocol {
    /// 纹理对象
    var texture: MTLTexture? { get }
}


/// 纹理提供者
class SYTextureProvider: SYTextureProviderProtocol {
    var texture: MTLTexture? = nil
    
    init(imageName: String, context: SYContext) {
        guard let path = Bundle.main.path(forResource: "LearnSwiftMetal", ofType: "bundle"),
        let bundle     = Bundle(path: path),
        let file       = bundle.path(forResource: imageName, ofType: nil) else {
            print("Can not find image file.")
            return
        }
        guard let image = UIImage(contentsOfFile: file) else {
            print("Load image file failure.")
            return
        }
        self.texture = self.textureFor(image: image, context: context)
    }
    
    // MARK: 创建纹理
    private func textureFor(image: UIImage, context: SYContext) -> MTLTexture? {
        // UIImage 的数据需要转成二进制才能上传，且不用 jpg、png 的 NSData
        guard let data = self.loadImage(image) else {
            print("Load image data failure.")
            return nil
        }
        // 纹理描述符
        let descriptor         = MTLTextureDescriptor()
        descriptor.pixelFormat = .rgba8Unorm            // 像素格式（RGBA）
        descriptor.width       = Int(image.size.width)    // 纹理-宽度
        descriptor.height      = Int(image.size.height)   // 纹理-高度
        descriptor.usage       = .shaderRead    // 原始纹理只需「读」权限
        // 创建纹理
        guard let texture = context.device.makeTexture(descriptor: descriptor) else {
            print("Create texture failed.")
            return nil
        }
        // 纹理上传范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(image.size.width),
                                             height: Int(image.size.height), depth: 1))
        // 拷贝图像数据到纹理
        texture.replace(region: region,
                        mipmapLevel: 0,
                        withBytes: data,
                        bytesPerRow: Int(image.size.width) * 4)
        return texture
    }
    
    // MARK: 加载图片数据（转成二进制）
    private func loadImage(_ image: UIImage) -> UnsafeMutableRawPointer? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        let width  = cgImage.width
        let height = cgImage.height
        let data   = UnsafeMutableRawPointer.allocate(byteCount: width * height * 4, alignment: 8)
        
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        // 创建画布
        let context = CGContext(data: data,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width * 4,
                                space: cgImage.colorSpace!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        // 在画布上绘制图片数据
        context?.draw(cgImage,
                      in: CGRect(x: 0, y: 0, width: width, height: height), byTiling: true)
        UIGraphicsEndImageContext()
        
        return data
    }
}
