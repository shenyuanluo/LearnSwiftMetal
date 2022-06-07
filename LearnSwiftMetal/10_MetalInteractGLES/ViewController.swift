//
//  ViewController.swift
//  10_MetalInteractGLES
//
//  Created by ShenYuanLuo on 2022/5/27.
//

import UIKit
import MetalKit

/**
 Metal 与 OpenGL-ES 交互
 Metal 纹理 ------------> CVPixelBuffer ------------> OpenGL-ES 纹理
 */
class ViewController: UIViewController {
    private var mtkView: MTKView!                           // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                          // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!              // 命令队列（控制渲染命令按部就班执行）
    private var renderPipeline: MTLRenderPipelineState!     // 图形渲染管线
    private var computePipeline: MTLComputePipelineState!   // 内核计算管线
    private var srcTexture: MTLTexture!                     // 原始-纹理对象
    private var destTexture: MTLTexture!                    // 结果-纹理对象
    private var renderPixelBuffer: CVPixelBuffer!
    private var viewportSize = vector_uint2(0, 0)           // 当前视图大小
    private var textureCache: CVMetalTextureCache!          // Core Video 的 Metal 纹理缓存
    
    private var vertices: MTLBuffer!                        // 顶点数据缓存
    private var numVertices: Int = 0                        // 顶点数量
    private var groupParams: MTLBuffer!
    private var groupSize: MTLSize = MTLSize(width: 16, height: 16, depth: 1)   // 每线程组线程大小（内核计算）
    private var groupCount: MTLSize = MTLSize(width: 16, height: 16, depth: 1)  // 每网格线程组大小（内核计算）
    
    private var imageView: UIImageView? = nil
    
    
    private lazy var glView: SYOpenGLView = {
        let view = SYOpenGLView(frame: CGRect(x: self.view.bounds.maxX - 160, y: 40, width: 160, height: 160))
        return view
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mtkView        = MTKView(frame: self.view.bounds)
        self.mtkView.device = MTLCreateSystemDefaultDevice()
        if nil == self.mtkView.device { // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        self.view             = self.mtkView
        self.device           = self.mtkView.device
        self.mtkView.delegate = self
        self.viewportSize     = vector_uint2(UInt32(self.mtkView.drawableSize.width), UInt32(self.mtkView.drawableSize.height))
        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.textureCache)
        
        self.view.addSubview(self.glView)
        
        self.glView.setupGL()
        
        self.customInit()
    }

    private func customInit() {
        self.setupPipeline()
        self.setupVertices()
        self.setupTexture()
        self.setupThreadGroup()
    }
    
    // MARK: 设置渲染管线
    private func setupPipeline() {
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
        // 内核计算（边缘检测）处理
        guard let sobelFun = library.makeFunction(name: "SobelCompute") else {
            print("Can not create sobel func.")
            return
        }        // 渲染管线描述符
        let descriptor                             = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction                  = vertexFun
        descriptor.fragmentFunction                = fragmentFun
        descriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat
        // 创建图形渲染管线（耗性能，不宜频繁操作）
        self.renderPipeline = try! self.device.makeRenderPipelineState(descriptor: descriptor)
        // 创建内核计算管线（耗性能，不宜频繁操作）
        self.computePipeline = try! self.device.makeComputePipelineState(function: sobelFun)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()
    }

    // MARK: 设置顶点数据缓存
    private func setupVertices() {
        let quadVertices = [   // 顶点坐标                                                                         纹理坐标
            SYVertex(position: [ 0.5, -0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [1.0, 1.0]), // 右下
            SYVertex(position: [-0.5, -0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [0.0, 1.0]), // 左下
            SYVertex(position: [-0.5,  0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [0.0, 0.0]), // 左上

            SYVertex(position: [ 0.5, -0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [1.0, 1.0]), // 右下
            SYVertex(position: [-0.5,  0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [0.0, 0.0]), // 左上
            SYVertex(position: [ 0.5,  0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [1.0, 0.0]), // 右上
        ]
        // 创建顶点数据缓存
        self.vertices = self.device.makeBuffer(bytes: quadVertices,
                                               length: MemoryLayout<SYVertex>.size * quadVertices.count,
                                               options: .storageModeShared)
        self.numVertices = quadVertices.count
    }
    
    // MARK: 设置纹理
    private func setupTexture() {
        guard let path = Bundle.main.path(forResource: "LearnSwiftMetal", ofType: "bundle"),
        let bundle     = Bundle(path: path),
        let file       = bundle.path(forResource: "Container", ofType: "jpg") else {
            print("Can not find image file.")
            return
        }
        guard let img = UIImage(contentsOfFile: file) else {
            print("Load image file failure.")
            return
        }
        // 纹理描述符
        let descriptor         = MTLTextureDescriptor()
        descriptor.pixelFormat = .rgba8Unorm            // 像素格式（RGBA）
        descriptor.width       = Int(img.size.width)    // 纹理-宽度
        descriptor.height      = Int(img.size.height)   // 纹理-高度
        self.srcTexture        = self.device.makeTexture(descriptor: descriptor)    // 创建纹理
        // 纹理上传范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(img.size.width), height: Int(img.size.height), depth: 1))
        // UIImage 的数据需要转成二进制才能上传，且不用 jpg、png 的 NSData
        guard let data = UIImage.loadImage(img) else {
            print("Load image data failure.")
            return
        }
        // 拷贝图像数据到纹理
        self.srcTexture.replace(region: region,
                                mipmapLevel: 0,
                                withBytes: data,
                                bytesPerRow: Int(img.size.width) * 4)
        
        self.setupRenderTarget(with: img.size)
    }
    
    // MARK: 设置线程组
    private func setupThreadGroup() {
        let width              = self.computePipeline.threadExecutionWidth
        let height             = self.computePipeline.maxTotalThreadsPerThreadgroup / width
        self.groupSize         = MTLSize(width: width, height: height, depth: 1)
        self.groupCount.width  = (self.srcTexture.width  + self.groupSize.width  - 1) / self.groupSize.width     // 确保每个像素都处理到
        self.groupCount.height = (self.srcTexture.height + self.groupSize.height - 1) / self.groupSize.height    // 确保每个像素都处理到
        self.groupCount.depth  = 1  // 2D 纹理，深度值为 1
        
        var params       = SYTransParam(kRec709Luma: [0.2126, 0.7152, 0.0722])
        self.groupParams = self.device.makeBuffer(bytes: &params,
                                                  length: MemoryLayout<SYTransParam>.size,
                                                  options: .storageModeShared)
    }
    
    // MARK: 绑定目的纹理渲染到像素缓存
    private func setupRenderTarget(with size: CGSize) {
        let attri = [kCVPixelBufferIOSurfacePropertiesKey : [:]]
        var pixelBuffer: CVPixelBuffer? = nil
        CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(size.width),
                            Int(size.height),
                            kCVPixelFormatType_32BGRA,
                            attri as CFDictionary,
                            &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            var texture: CVMetalTexture? = nil
            let width  = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let status = CVMetalTextureCacheCreateTextureFromImage(nil,
                                                                   self.textureCache,
                                                                   pixelBuffer,
                                                                   nil,
                                                                   .rgba8Unorm,
                                                                   width,
                                                                   height,
                                                                   0,
                                                                   &texture)
            if status == kCVReturnSuccess {
                self.destTexture       = CVMetalTextureGetTexture(texture!)
                self.renderPixelBuffer = pixelBuffer
            } else {
                print("CVMetal texture cache create texture from image fail.")
            }
        } else {
            print("Create CV PixelBuffer failed.")
        }
    }
}


extension ViewController: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportSize = vector_uint2(UInt32(size.width), UInt32(size.height))
    }
    
    public func draw(in view: MTKView) {
        // 每次渲染都要单独创建一个 CommandBuffer
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("Create command buffer failure.")
            return
        }
        commandBuffer.label = "SY-command"
        // 内核计算渲染到纹理
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.label = "SY-ComputeEncoder"
            // 设置内核计算管线（以调用 shaders.metal 中的内核计算函数）
            computeEncoder.setComputePipelineState(self.computePipeline)
            // 设置输入纹理
            computeEncoder.setTexture(self.srcTexture,
                                      index: Int(SYComputeTextureIndexSrc.rawValue))
            // 设置输出纹理
            computeEncoder.setTexture(self.destTexture,
                                      index: Int(SYComputeTextureIndexDest.rawValue))
            computeEncoder.setThreadgroupMemoryLength((MemoryLayout<vector_float3>.size + 15) / 16 * 16, index: 0)
            computeEncoder.setBuffer(self.groupParams, offset: 0, index: 0)
            // 设置计算区域
            computeEncoder.dispatchThreadgroups(self.groupCount,
                                                threadsPerThreadgroup: self.groupSize)
            // 结束，释放编码器，下个 encoder 才能创建
            computeEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { buff in
                if kCVReturnSuccess == CVPixelBufferLockBaseAddress(self.renderPixelBuffer, .readOnly) {
                    DispatchQueue.main.async {
                        let image = UIImage.imageWith(pixelBuffer: self.renderPixelBuffer)
                        if nil == self.imageView {
                            self.imageView = UIImageView(image: image)
                            self.imageView?.frame = CGRect(x: 0, y: 40, width: 160, height: 160)
                            self.view.addSubview(self.imageView!)
                        }
                        // OpenGL-ES 渲染
                        self.glView.display(self.renderPixelBuffer)
                        CVPixelBufferUnlockBaseAddress(self.renderPixelBuffer, .readOnly)
                    }
                }
            }
        }
        // MTLRenderPassDescriptor 描述一系列 attachments 的值，类似 OpenGL 的 FrameBuffer；同时也用来创建 MTLRenderCommandEncoder
        guard let descriptor = view.currentRenderPassDescriptor else {
            return
        }
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0)  // 设置默认颜色
        descriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        // 创建渲染命令编码器
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            renderEncoder.label = "SY-RenderEncoder"
            let viewport = MTLViewport(originX: 0,
                                       originY: 0,
                                       width: Double(self.viewportSize.x),
                                       height: Double(self.viewportSize.y),
                                       znear: -1.0,
                                       zfar: 1.0)
            // 设置显示区域
            renderEncoder.setViewport(viewport)
            // 设置渲染管线（以保证「顶点」和「片段」两个 shader 会被调用）
            renderEncoder.setRenderPipelineState(self.renderPipeline)
            // 设置顶点缓存
            renderEncoder.setVertexBuffer(self.vertices,
                                          offset: 0,
                                          index: Int(SYVertexInputIndexVertices.rawValue))
            // 设置纹理
            renderEncoder.setFragmentTexture(self.destTexture, index: 0)
            // 开始绘制
            renderEncoder.drawPrimitives(type: .triangle,
                                         vertexStart: 0,
                                         vertexCount: self.numVertices)
            renderEncoder.endEncoding() // 结束
            commandBuffer.present(view.currentDrawable!)    // 显示
        }
        commandBuffer.commit()  // 提交
    }
    
}

