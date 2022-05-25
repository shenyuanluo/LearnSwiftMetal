//
//  ViewController.swift
//  07_RenderVideo
//
//  Created by ShenYuanLuo on 2022/5/25.
//

import UIKit
import MetalKit
import CoreMedia

class ViewController: UIViewController {
    private var mtkView: MTKView!                           // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                          // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!              // 命令队列（控制渲染命令按部就班执行）
    private var renderPipeline: MTLRenderPipelineState!     // 图形渲染管线
    private var viewportSize = CGSize(width: 0, height: 0)  // 当前视图大小
    private var vertices: MTLBuffer!                        // 顶点数据缓存
    private var numVertices: Int = 0                        // 顶点数量
    private var covertMatrix: MTLBuffer!                    // 转换矩阵缓存
    private var textureCache: CVMetalTextureCache!          // Core Video 的 Metal 纹理缓存
    
    private var reader: SYAssetReader!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mtkView        = MTKView(frame: self.view.bounds)
        self.mtkView.device = MTLCreateSystemDefaultDevice()
        if nil == self.mtkView.device { // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        self.view             = self.mtkView
        self.mtkView.delegate = self
        self.device           = self.mtkView.device
        self.viewportSize     = CGSize(width: self.mtkView.drawableSize.width, height: self.mtkView.drawableSize.height)
        
        guard let path = Bundle.main.path(forResource: "LearnSwiftMetal", ofType: "bundle"),
        let bundle     = Bundle(path: path),
        let url        = bundle.url(forResource: "Time", withExtension: "mov") else {
            print("Can not find video file.")
            return
        }
        self.reader = SYAssetReader(videoUrl: url)
        
        // 创建纹理缓存区
        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.textureCache)
        
        self.customInit()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    private func customInit() {
        self.setupPipeline()
        self.setupVertices()
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

    // MARK: 设置顶点数据缓存
    private func setupVertices() {
        // 按视频比例显示
        let viewWidth    = Float(self.viewportSize.width)
        let viewHeight   = Float(self.viewportSize.height)
        let videoWidth   = Float(480)
        let videoHeight  = Float(720)
        var renderWidth  = Float(viewWidth)
        var renderHeight = Float(viewHeight)

        if viewWidth / viewHeight > videoWidth / videoHeight {
            renderWidth = renderHeight * videoWidth / videoHeight
        } else {
            renderHeight = renderWidth * videoHeight / videoWidth
        }
        let quadVertices = [ // 顶点坐标                                             纹理坐标
            SYVertex(position: [ 1.0, -1.0 * renderHeight / viewHeight, 0.0, 1.0], textureCoordinate: [1.0, 1.0]), // 右下
            SYVertex(position: [-1.0, -1.0 * renderHeight / viewHeight, 0.0, 1.0], textureCoordinate: [0.0, 1.0]), // 左下
            SYVertex(position: [-1.0,  1.0 * renderHeight / viewHeight, 0.0, 1.0], textureCoordinate: [0.0, 0.0]), // 左上
            
            SYVertex(position: [ 1.0, -1.0 * renderHeight / viewHeight, 0.0, 1.0], textureCoordinate: [1.0, 1.0]), // 右下
            SYVertex(position: [-1.0,  1.0 * renderHeight / viewHeight, 0.0, 1.0], textureCoordinate: [0.0, 0.0]), // 左上
            SYVertex(position: [ 1.0,  1.0 * renderHeight / viewHeight, 0.0, 1.0], textureCoordinate: [1.0, 0.0]), // 右上
        ]
        // 创建顶点数据缓存
        self.vertices = self.device.makeBuffer(bytes: quadVertices,
                                               length: MemoryLayout<SYVertex>.size * quadVertices.count,
                                               options: .storageModeShared)
        self.numVertices = quadVertices.count
    }
    
    // MARK: 设置转换矩阵
    private func setupMatrix() {
        /*
        // BT.601, which is the standard for SDTV.
        let matrix601Default = matrix_float3x3(SIMD3(1.164,  1.164, 1.164),
                                               SIMD3(0.0,   -0.392, 2.017),
                                               SIMD3(1.596, -0.813, 0.0))
        
        // BT.709, which is the standard for HDTV.
        let matrix709Default = matrix_float3x3(SIMD3(1.164,  1.164, 1.164),
                                               SIMD3(0.0,   -0.213, 2.112),
                                               SIMD3(1.793, -0.533, 0.0))
        */
        // BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
        let matrix601FullRange = matrix_float3x3(SIMD3(1.0,  1.0,   1.0),
                                                 SIMD3(0.0, -0.343, 1.765),
                                                 SIMD3(1.4, -0.711, 0.0))
        let offset601FullRange = vector_float3(-(16.0/255.0), -0.5, -0.5)
        var matrix    = SYConvertMatrix()
        matrix.matrix = matrix601FullRange
        matrix.offset = offset601FullRange
        self.covertMatrix = self.device.makeBuffer(bytes: &matrix,
                                                   length: MemoryLayout<SYConvertMatrix>.size,
                                                   options: .storageModeShared)
    }
    
    private func setupTextureWith(encoder: MTLRenderCommandEncoder, buffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            print("Can not get pixel buffer")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        var textureY: MTLTexture? = nil
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
            encoder.setFragmentTexture(textureY, index: Int(SYFragmentTextureIndexY.rawValue))
            encoder.setFragmentTexture(textureUV, index: Int(SYFragmentTextureIndexUV.rawValue))
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
}


extension ViewController: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportSize = CGSize(width: size.width, height: size.height)
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
              let buffer = self.reader.readBuffer() else {
            return
        }
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0)  // 设置默认颜色
        descriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        // 创建渲染命令编码器
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            renderEncoder.label = "SY-RenderEncoder"
            let viewport = MTLViewport(originX: 0,
                                       originY: 0,
                                       width: Double(self.viewportSize.width),
                                       height: Double(self.viewportSize.height),
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
            self.setupTextureWith(encoder: renderEncoder, buffer: buffer)
            // 设置矩阵缓存
            renderEncoder.setFragmentBuffer(self.covertMatrix,
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

