//
//  ViewController.swift
//  Sec12_VideoCompositing
//
//  Created by ShenYuanLuo on 2022/6/8.
//

import UIKit
import MetalKit
import CoreMedia

class ViewController: UIViewController {
    private var mtkView: MTKView!                               // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                              // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!                  // 命令队列（控制渲染命令按部就班执行）
    private var renderPipeline: MTLRenderPipelineState!         // 图形渲染管线
    private var greenTexture: MTLTexture!                       // 绿幕-纹理对象
    private var normalTexture: MTLTexture!                      // 正常-纹理对象
    private var vertices: MTLBuffer!                            // 顶点数据缓存
    private var numVertices: Int = 0                            // 顶点数量
    private var convertMatrix: MTLBuffer!                       // 统计颜色缓存
    private var viewportSize = vector_uint2(0, 0)               // 当前视图大小
    private var textureCache: CVMetalTextureCache!              // Core Video 的 Metal 纹理缓存
    
    private var greenReader: SYAssetReader!
    private var normalReader: SYAssetReader!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mtkView        = MTKView(frame: self.view.bounds)
        self.mtkView.device = MTLCreateSystemDefaultDevice()
        if nil == self.mtkView.device { // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        self.device           = self.mtkView.device
        self.mtkView.delegate = self
        self.viewportSize     = vector_uint2(UInt32(self.mtkView.drawableSize.width),
                                             UInt32(self.mtkView.drawableSize.height))
        self.view.insertSubview(self.mtkView, at: 0)
        
        
        guard let path = Bundle.main.path(forResource: "LearnSwiftMetal", ofType: "bundle"),
        let bundle     = Bundle(path: path),
        let greenUrl   = bundle.url(forResource: "GreenScreenVideo", withExtension: "mp4"),
        let normalUrl  =  bundle.url(forResource: "Time", withExtension: "mov")  else {
            print("Can not find video file.")
            return
        }
        self.greenReader  = SYAssetReader(videoUrl: greenUrl)
        self.normalReader = SYAssetReader(videoUrl: normalUrl)
        
        self.customInit()
        
        // 创建纹理缓存区
        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.textureCache)
    }


    private func customInit() {
        self.setupPipeline()
        self.setupVertex()
        self.setupMatrix()
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
        // 渲染管线描述符
        let descriptor                             = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction                  = vertexFun
        descriptor.fragmentFunction                = fragmentFun
        descriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat
        // 创建图形渲染管线（耗性能，不宜频繁操作）
        self.renderPipeline = try! self.device.makeRenderPipelineState(descriptor: descriptor)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()
    }
    
    // MARk: 设置顶点
    private func setupVertex() {
        let quadVertices: [SYVertex] = [
            // 第一个三角形
            SYVertex(position: [ 1.0, -1.0, 0.0, 1.0], textureCoordinate: [1.0, 1.0]),   // 右下
            SYVertex(position: [-1.0, -1.0, 0.0, 1.0], textureCoordinate: [0.0, 1.0]),   // 左下
            SYVertex(position: [-1.0,  1.0, 0.0, 1.0], textureCoordinate: [0.0, 0.0]),   // 左上
            // 第二个三角形
            SYVertex(position: [ 1.0, -1.0, 0.0, 1.0], textureCoordinate: [1.0, 1.0]),   // 右下
            SYVertex(position: [-1.0,  1.0, 0.0, 1.0], textureCoordinate: [0.0, 0.0]),   // 左上
            SYVertex(position: [ 1.0,  1.0, 0.0, 1.0], textureCoordinate: [1.0, 0.0]),   // 右上
        ];
        // 创建顶点数据缓存
        self.vertices = self.device.makeBuffer(bytes: quadVertices,
                                               length: MemoryLayout<SYVertex>.size * quadVertices.count,
                                               options: .storageModeShared)
        self.numVertices = quadVertices.count
    }
    
    // MARK: 设置矩阵
    private func setupMatrix() {
        let matrix601FullRange = matrix_float3x3(SIMD3(1.0,  1.0,   1.0),
                                                 SIMD3(0.0, -0.343, 1.765),
                                                 SIMD3(1.4, -0.711, 0.0))
        let offset601FullRange = vector_float3(-(16.0/255.0), -0.5, -0.5)
        var matrix    = SYConvertMatrix()
        matrix.matrix = matrix601FullRange
        matrix.offset = offset601FullRange
        self.convertMatrix = self.device.makeBuffer(bytes: &matrix,
                                                   length: MemoryLayout<SYConvertMatrix>.size,
                                                   options: .storageModeShared)
    }
    
    // MARK: 设置纹理
    private func setupTextureWith(encoder: MTLRenderCommandEncoder, buffer: CMSampleBuffer, isGreen: Bool) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            print("Can not get pixel buffer")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        var textureY: MTLTexture?  = nil
        var textureUV: MTLTexture? = nil
        
        // Y 纹理设置
        var tmpTextureY: CVMetalTexture? = nil
        let widthY  = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let heightY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let formatY = MTLPixelFormat.r8Unorm // 这里像素格式不是 RGBA（1-8 bit 格式）
        let statusY = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                self.textureCache,
                                                                pixelBuffer,
                                                                nil,
                                                                formatY,
                                                                widthY,
                                                                heightY,
                                                                0,
                                                                &tmpTextureY)
        if kCVReturnSuccess == statusY {
            textureY = CVMetalTextureGetTexture(tmpTextureY!)    // 转成 Metal 纹理
        }
        // UV 纹理设置
        var tmpTextureUV: CVMetalTexture? = nil
        let widthUV  = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let heightUV = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        let formatUV = MTLPixelFormat.rg8Unorm // 这里像素格式不是 RGBA（2-8 bit 格式）
        let statusUV = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                self.textureCache,
                                                                pixelBuffer,
                                                                nil,
                                                                formatUV,
                                                                widthUV,
                                                                heightUV,
                                                                1,
                                                                &tmpTextureUV)
        if kCVReturnSuccess == statusUV {
            textureUV = CVMetalTextureGetTexture(tmpTextureUV!)    // 转成 Metal 纹理
        }
        // 设置纹理
        if nil != textureY && nil != textureUV {
            if true == isGreen {
                encoder.setFragmentTexture(textureY, index: Int(SYFragmentTextureIndexGreenTextureY.rawValue))
                encoder.setFragmentTexture(textureUV, index: Int(SYFragmentTextureIndexGreenTextureUV.rawValue))
            } else {
                encoder.setFragmentTexture(textureY, index: Int(SYFragmentTextureIndexNormalTextureY.rawValue))
                encoder.setFragmentTexture(textureUV, index: Int(SYFragmentTextureIndexNormalTextureUV.rawValue))
            }
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
}


extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportSize = vector_uint2(UInt32(size.width), UInt32(size.height))
    }
    
    func draw(in view: MTKView) {
        // 每次渲染都要单独创建一个 CommandBuffer
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("Create command buffer failure.")
            return
        }
        commandBuffer.label = "SY-command"
        // MTLRenderPassDescriptor 描述一系列 attachments 的值，类似 OpenGL 的 FrameBuffer；同时也用来创建 MTLRenderCommandEncoder
        guard let descriptor = view.currentRenderPassDescriptor,
              let greenBuffer = self.greenReader.readBuffer(),
              let normalBuffer = self.normalReader.readBuffer() else {
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
            self.setupTextureWith(encoder: renderEncoder, buffer: greenBuffer, isGreen: true)
            self.setupTextureWith(encoder: renderEncoder, buffer: normalBuffer, isGreen: false)
            
            // 设置矩阵缓存
            renderEncoder.setFragmentBuffer(self.convertMatrix,
                                            offset: 0,
                                            index: Int(SYFragmentBufferIndexMatrix.rawValue))
            // 开始绘制
            renderEncoder.drawPrimitives(type: .triangle,
                                         vertexStart: 0,
                                         vertexCount: self.numVertices)
            renderEncoder.endEncoding() // 结束
        }
        commandBuffer.present(view.currentDrawable!)    // 显示
        
        commandBuffer.commit()  // 提交
    }
}
