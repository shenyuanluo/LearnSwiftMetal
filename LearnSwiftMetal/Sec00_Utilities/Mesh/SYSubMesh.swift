//
//  SYSubMesh.swift
//  LearnSwiftMetal
//
//  Created by ShenYuanLuo on 2022/6/14.
//

import MetalKit

struct SYSubMesh {
    /// MTKSubmesh 包含图元类型、索引缓存、索引数量（可以用于部分/全部 Mesh）
    let metalKitSubmesh: MTKSubmesh
    /// 材质
    var material: SYMaterial?


    init(metalKitSubmesh: MTKSubmesh) {
        self.metalKitSubmesh = metalKitSubmesh
    }

    init(modelIOSubmesh: MDLSubmesh, metalKitSubmesh: MTKSubmesh, textureLoader: MTKTextureLoader) {
        self.metalKitSubmesh = metalKitSubmesh

        if let mdlMaterial = modelIOSubmesh.material {
            self.material = SYMaterial(mdlMaterial: mdlMaterial, textureLoader: textureLoader)
        }
    }

}
