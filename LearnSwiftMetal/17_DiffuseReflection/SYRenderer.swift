//
//  SYRenderer.swift
//  17_DiffuseReflection
//
//  Created by ShenYuanLuo on 2022/6/16.
//

import MetalKit

/// GPU-渲染器
class SYRenderer: NSObject {
    private var device: MTLDevice!                              // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!                  // 命令队列（控制渲染命令按部就班执行）
    private var renderPipeline: MTLRenderPipelineState!         // 图形渲染管线
    private var depthPipeline: MTLDepthStencilState!            // 深度模板测试
    private var uniformBuffer: MTLBuffer!                       // Uniform-缓存
    private lazy var vertexDescriptor: MTLVertexDescriptor = {  // 顶点属性描述
        let descriptor = MTLVertexDescriptor()
        // 顶点-位置
        descriptor.attributes[Int(SYVertexAttributePosition.rawValue)].format      = .float3
        descriptor.attributes[Int(SYVertexAttributePosition.rawValue)].offset      = 0
        descriptor.attributes[Int(SYVertexAttributePosition.rawValue)].bufferIndex = 0
        // 纹理-坐标
        descriptor.attributes[Int(SYVertexAttributeTexCoord.rawValue)].format      = .float2
        descriptor.attributes[Int(SYVertexAttributeTexCoord.rawValue)].offset      = 12
        descriptor.attributes[Int(SYVertexAttributeTexCoord.rawValue)].bufferIndex = 0
        // 法线
        descriptor.attributes[Int(SYVertexAttributeNormal.rawValue)].format      = .half4
        descriptor.attributes[Int(SYVertexAttributeNormal.rawValue)].offset      = 20
        descriptor.attributes[Int(SYVertexAttributeNormal.rawValue)].bufferIndex = 0
        // 内存布局
        // 模型中每个顶点包含 position(float3)、uv(float2)、normal(half4)、tangent(half4)、bitangent(half4)五个属性，
        // 数据长度为: 3x4 + 2x4 + 4x2 + 4x2 + 4x2 = 44
        descriptor.layouts[0].stride       = 44
        descriptor.layouts[0].stepRate     = 1
        descriptor.layouts[0].stepFunction = .perVertex
        return descriptor
    }()
    
    private var meshes: [SYMesh] = []   // 网格数组
    private var rotationAngle: Float = 0
    private var projectionMatrix: matrix_float4x4!   // 投影矩阵
    
    
    init(mtkView: MTKView) {
        super.init()
        
        self.device = mtkView.device
        self.setupPipeline(mtkView: mtkView)
        self.setupBuffer()
        self.loadAssets()
    }
    
    // MARK: 设置渲染管线
    private func setupPipeline(mtkView: MTKView) {
        mtkView.depthStencilPixelFormat = .depth32Float_stencil8
        mtkView.colorPixelFormat        = .bgra8Unorm_srgb
        mtkView.sampleCount             = 1
        
        // 从 Bundle 加载所有着色器文件（.metal）
        guard let library = self.device.makeDefaultLibrary() else {
            print("Can not create (.metal) library.")
            return
        }
        // 加载顶点着色器（VertexShader 是函数名称）
        guard let vertexFun = library.makeFunction(name: "VertexShader") else {
            print("Can not create vertex shader.")
            return
        }
        // 加载片段着色器（FragmentShader 是函数名称）
        guard let fragmentFun = library.makeFunction(name: "FragmentShader") else {
            print("Can not create fragment shader.")
            return
        }
        // 渲染管线描述符
        let descriptor                             = MTLRenderPipelineDescriptor()
        descriptor.label                           = "Forward Lighting"
        descriptor.sampleCount                     = mtkView.sampleCount
        descriptor.vertexDescriptor                = self.vertexDescriptor
        descriptor.vertexFunction                  = vertexFun
        descriptor.fragmentFunction                = fragmentFun
        descriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        descriptor.depthAttachmentPixelFormat      = mtkView.depthStencilPixelFormat
        descriptor.stencilAttachmentPixelFormat    = mtkView.depthStencilPixelFormat
        // 创建图形渲染管线（耗性能，不宜频繁操作）
        do {
            self.renderPipeline = try self.device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error as NSError {
            print("Failed to create render pipeline state: \(error.localizedDescription)")
        } catch {
            print("Failed to create render pipeline state.")
        }
        // 创建深度模板测试 state
        let depthDescriptor                  = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual   // 深度测试「函数」
        depthDescriptor.isDepthWriteEnabled  = true // 更新深度缓存数据
        self.depthPipeline                   = self.device.makeDepthStencilState(descriptor: depthDescriptor)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()
    }
    
    private func setupBuffer() {
        self.uniformBuffer = self.device.makeBuffer(length: MemoryLayout<SYUniforms>.size,
                                                    options: .storageModeShared)
    }
    
    // MARK: 加载模型
    private func loadAssets() {
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(self.vertexDescriptor)
        (modelIOVertexDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (modelIOVertexDescriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        (modelIOVertexDescriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        guard let path         = Bundle.main.path(forResource: "LearnSwiftMetal", ofType: "bundle"),
              let bundle       = Bundle(path: path),
              let modelFileURL = bundle.url(forResource: "Meshes/Temple", withExtension: "obj") else {
            print("Can not find temple model obj file.")
            return
        }
        self.meshes = SYMesh.loadMeshes(url: modelFileURL,
                                        vertexDescriptor: modelIOVertexDescriptor,
                                        device: self.device)
    }
    
    // MARK: 更新矩阵
    private func updateGameState() {
        let uniforms    = self.uniformBuffer.contents().assumingMemoryBound(to: SYUniforms.self)
        let moveToZ     = SYTransform.translationMatrix(SIMD3<Float>(0, 0, 1000))  // 往 Z 轴方向平移，将相机拉远（以容下整个场景）
        let radian      = SYTransform.radian(-30)   // 旋转弧度
        let rotateX     = SYTransform.rotationMatrix(radians: radian, axis: SIMD3<Float>(1, 0, 0)) // 绕 X 轴逆时针旋转（略微抬高相机俯视原点）
        let modelMatrix = moveToZ * rotateX // matrix_multiply(moveToZ, rotateX)
        let viewMatrix  = SYTransform.rotationMatrix(radians: SYTransform.radian(self.rotationAngle),
                                                     axis: SIMD3<Float>(0, 1, 0))    // 持续绕 Y 轴旋转
        // 更新 MVP 矩阵
        uniforms.pointee.modelMatrix      = modelMatrix
        uniforms.pointee.viewMatrix       = viewMatrix
        uniforms.pointee.modelViewMatrix  = modelMatrix * viewMatrix  // matrix_multiply(modelMatrix, viewMatrix)
        uniforms.pointee.projectionMatrix = self.projectionMatrix
        // 更新平行光照
        uniforms.pointee.directionalLightDirection = vector_float3(-1.0, -1.0, -1.0)    // 光照方向向量
        uniforms.pointee.directionalLightColor = vector_float3(0.8, 0.8, 0.8)   // 光照颜色向量
        uniforms.pointee.IL = 10.0  // 光源强度
        uniforms.pointee.Kd = 0.1   // 漫反射系数

        self.rotationAngle += 0.25   // 每帧转动角度
    }
    
    // MARK: 绘制网格
    private func drawMeshes(_ renderEncoder: MTLRenderCommandEncoder) {
        for mesh in self.meshes {
            let metalKitMesh = mesh.metalKitMesh
            for bufferIndex in 0..<metalKitMesh.vertexBuffers.count {
                let vertexBuffer = metalKitMesh.vertexBuffers[bufferIndex]
                renderEncoder.setVertexBuffer(vertexBuffer.buffer,
                                              offset: vertexBuffer.offset,
                                              index: bufferIndex)
            }
            
            for subMesh in mesh.submeshes {
                if let material = subMesh.material {
                    renderEncoder.setFragmentTexture(material.baseColor,
                                                     index: Int(SYTextureIndexColor.rawValue))
                    renderEncoder.setFragmentTexture(material.specular,
                                                     index: Int(SYTextureIndexNormal.rawValue))
                    renderEncoder.setFragmentTexture(material.normal,
                                                     index: Int(SYTextureIndexSpecular.rawValue))
                }
                renderEncoder.setFragmentBuffer(self.uniformBuffer,
                                              offset: 0,
                                              index: Int(SYBufferIndexUniform.rawValue))
                let metalKitSubmesh = subMesh.metalKitSubmesh
                renderEncoder.drawIndexedPrimitives(type: metalKitSubmesh.primitiveType,
                                                    indexCount: metalKitSubmesh.indexCount,
                                                    indexType: metalKitSubmesh.indexType,
                                                    indexBuffer: metalKitSubmesh.indexBuffer.buffer,
                                                    indexBufferOffset: metalKitSubmesh.indexBuffer.offset)
            }
        }
    }
}


extension SYRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // 更新透视投影矩阵
        let aspect            = Float(size.width) / Float(size.height)
        let fov               = Float(65) * Float(Float.pi / 180.0)
        let nearPlane         = Float(1)
        let farPlane          = Float(1500)
        self.projectionMatrix = SYTransform.perspectiveProjection(fov, aspect, nearPlane, farPlane)
    }
    
    func draw(in view: MTKView) {
        // 每次渲染都要单独创建一个 CommandBuffer
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("Create command buffer failure.")
            return
        }
        commandBuffer.label = "SY-command"
        
        self.updateGameState()
        
        // MTLRenderPassDescriptor 描述一系列 attachments 的值，类似 OpenGL 的 FrameBuffer；同时也用来创建 MTLRenderCommandEncoder
        guard let descriptor = view.currentRenderPassDescriptor else {
            return
        }
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0)  // 设置默认颜色
        descriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        // 创建渲染命令编码器
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            renderEncoder.label = "SY-RenderEncoder"
            renderEncoder.setCullMode(.back)    // 背面剔除
            renderEncoder.pushDebugGroup("Render Forward Lighting")
            
            renderEncoder.setRenderPipelineState(self.renderPipeline)
            renderEncoder.setDepthStencilState(self.depthPipeline)
            renderEncoder.setVertexBuffer(self.uniformBuffer,
                                          offset: 0,
                                          index: Int(SYBufferIndexUniform.rawValue))
            
            self.drawMeshes(renderEncoder)
            
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding() // 结束
        }
        commandBuffer.present(view.currentDrawable!) // 显示
        commandBuffer.commit()  // 提交
    }
}

