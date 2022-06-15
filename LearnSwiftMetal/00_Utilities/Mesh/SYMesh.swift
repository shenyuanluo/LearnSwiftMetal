//
//  SYMesh.swift
//  LearnSwiftMetal
//
//  Created by ShenYuanLuo on 2022/6/14.
//

import MetalKit

struct SYMesh {
    let metalKitMesh: MTKMesh
    let submeshes: [SYSubMesh]


    init(metalKitMesh: MTKMesh) {
        self.metalKitMesh = metalKitMesh

        var submeshes = [SYSubMesh]()
        for metalKitSubmesh in metalKitMesh.submeshes {
            submeshes.append(SYSubMesh(metalKitSubmesh: metalKitSubmesh))
        }
        self.submeshes = submeshes
    }

    init(modelIOMesh: MDLMesh,
         vertexDescriptor: MDLVertexDescriptor,
         textureLoader: MTKTextureLoader,
         device: MTLDevice) {
        modelIOMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                    normalAttributeNamed: MDLVertexAttributeNormal,
                                    tangentAttributeNamed: MDLVertexAttributeTangent)
        modelIOMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                    tangentAttributeNamed: MDLVertexAttributeTangent,
                                    bitangentAttributeNamed: MDLVertexAttributeBitangent)
        modelIOMesh.vertexDescriptor = vertexDescriptor

        do {
            let metalKitMesh = try MTKMesh(mesh: modelIOMesh, device: device)
            assert(metalKitMesh.submeshes.count == modelIOMesh.submeshes?.count)
            self.metalKitMesh = metalKitMesh
        } catch {
            fatalError("Failed to create MTKMesh from MDLMesh: \(error.localizedDescription)")
        }

        var submeshes = [SYSubMesh]()

        for index in 0..<self.metalKitMesh.submeshes.count {
            if let modelIOMesh = modelIOMesh.submeshes?.object(at: index) as? MDLSubmesh {
                let subMesh = SYSubMesh(modelIOSubmesh: modelIOMesh,
                                        metalKitSubmesh: self.metalKitMesh.submeshes[index],
                                        textureLoader: textureLoader)
                submeshes.append(subMesh)
            }
        }

        self.submeshes = submeshes
    }

    // MARK: 通过 URL 加载 Mesh
    static func loadMeshes(url: URL,
                           vertexDescriptor: MDLVertexDescriptor,
                           device: MTLDevice) -> [SYMesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)

        let asset = MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: bufferAllocator)

        let textureLoader = MTKTextureLoader(device: device)

        var meshes = [SYMesh]()

        for child in asset.childObjects(of: MDLObject.self) {
            let assetMeshes = self.makeMeshes(object: child,
                                              vertexDescriptor: vertexDescriptor,
                                              textureLoader: textureLoader,
                                              device: device)
            meshes.append(contentsOf: assetMeshes)
        }
        return meshes
    }

    // MARK: 通过 MDL 对象创建 Mesh
    static private func makeMeshes(object: MDLObject,
                           vertexDescriptor: MDLVertexDescriptor,
                           textureLoader: MTKTextureLoader,
                           device: MTLDevice) -> [SYMesh] {
        var meshes = [SYMesh]()

        if let mesh = object as? MDLMesh {
            let newMesh = SYMesh(modelIOMesh: mesh,
                                 vertexDescriptor: vertexDescriptor,
                                 textureLoader: textureLoader,
                                 device: device)
            meshes.append(newMesh)
        }

        if object.conforms(to: MDLObjectContainerComponent.self) {
            for child in object.children.objects {
                let childMeshes = self.makeMeshes(object: child,
                                                  vertexDescriptor: vertexDescriptor,
                                                  textureLoader: textureLoader,
                                                  device: device)
                meshes.append(contentsOf: childMeshes)
            }
        }

        return meshes
    }
}
