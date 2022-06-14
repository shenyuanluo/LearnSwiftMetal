//
//  SYMaterial.swift
//  15_LoadingObjModel
//
//  Created by ShenYuanLuo on 2022/6/14.
//

import MetalKit

/// 材质结构体
struct SYMaterial {
    /// 颜色-纹理
    var baseColor: MTLTexture
    /// 法线-纹理
    var normal: MTLTexture
    /// 镜面反射-纹理
    var specular: MTLTexture

    init(mdlMaterial: MDLMaterial, textureLoader: MTKTextureLoader) {
        self.baseColor = SYMaterial.makeTextureFrom(material: mdlMaterial,
                                                    materialSematic: .baseColor,
                                                    textureLoader: textureLoader)
        self.normal = SYMaterial.makeTextureFrom(material: mdlMaterial,
                                                 materialSematic: .tangentSpaceNormal,
                                                 textureLoader: textureLoader)
        self.specular = SYMaterial.makeTextureFrom(material: mdlMaterial,
                                                   materialSematic: .specular,
                                                   textureLoader: textureLoader)
    }

    // MARK: 创建纹理
    static private func makeTextureFrom(material: MDLMaterial,
                                        materialSematic: MDLMaterialSemantic,
                                        textureLoader: MTKTextureLoader) -> MTLTexture {
        var newTexture: MTLTexture!

        for property in material.properties(with: materialSematic) {
            // 加载纹理-选项
            let textureLoaderOptions: [MTKTextureLoader.Option : Any] = [
                .textureUsage       : MTLTextureUsage.shaderRead.rawValue,  // 读-共享
                .textureStorageMode : MTLStorageMode.private.rawValue       // 私有-存储（GPU）
            ]

            switch property.type {
            case .string:
                if let textureName = property.stringValue { // 通过「名称」加载
                    do {
                      newTexture = try textureLoader.newTexture(name: textureName,
                                                                scaleFactor: 1.0,
                                                                bundle: nil,
                                                                options: textureLoaderOptions)
                    } catch let error as NSError {
                        print("Failed to load texture with name: \(error.localizedDescription)")
                    } catch {
                        print("Failed to load texture with name.")
                    }
                }
            case .URL:
                if let textureURL = property.urlValue { // 通过「URL」加载
                    do {
                        newTexture = try textureLoader.newTexture(URL: textureURL,
                                                                  options: textureLoaderOptions)
                    } catch let error as NSError {
                        print("Failed to load texture with url: \(error.localizedDescription)")
                    } catch {
                        print("Failed to load texture with url.")
                    }
                }
            default:
                fatalError("Texture data for material property not found.")
            }
        }
        return newTexture
    }
}
