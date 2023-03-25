//
//  SYTextureProvider.swift
//  Sec06_ImageProcessing
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
        guard let data = UIImage.loadImage(image) else {
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
}
