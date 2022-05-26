//
//  ViewController.swift
//  08_SobelEdgeDetector
//
//  Created by ShenYuanLuo on 2022/5/25.
//

import UIKit
import MetalKit
import AVFoundation

class ViewController: UIViewController {
    private var mtkView: MTKView!                           // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                          // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!              // 命令队列（控制渲染命令按部就班执行）
    private var renderPipeline: MTLRenderPipelineState!     // 图形渲染管线
    private var computePipeline: MTLComputePipelineState!   // 内核计算管线
    private var srcTexture: MTLTexture!                     // 原始-纹理对象
    private var destTexture: MTLTexture!                    // 结果-纹理对象
    
    private var viewportSize = CGSize(width: 0, height: 0)  // 当前视图大小
    private var vertices: MTLBuffer!                        // 顶点数据缓存
    private var numVertices: Int = 0                        // 顶点数量
    private var groupSize: MTLSize = MTLSize(width: 16, height: 16, depth: 1)   // 每线程组线程大小（内核计算）
    private var groupCount: MTLSize = MTLSize(width: 16, height: 16, depth: 1)  // 每网格线程组大小（内核计算）
    
    private var textureCache: CVMetalTextureCache!      // Core Video 的 Metal 纹理缓存
    private var captureSession: AVCaptureSession!       // 相机会话
    private var captureInput: AVCaptureDeviceInput!     // 相机输入
    private var captureOutput: AVCaptureVideoDataOutput!// 视频输出
    private let processQueue = DispatchQueue(label: "com.sy.processQueue")
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupMetal()
        
        self.customInit()
    }
    
    // MARK: 设置 Metal
    private func setupMetal() {
        self.mtkView        = MTKView(frame: self.view.bounds)
        self.mtkView.device = MTLCreateSystemDefaultDevice()
        if nil == self.mtkView.device { // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        self.mtkView.delegate = self
        self.device           = self.mtkView.device
        self.viewportSize     = CGSize(width: self.mtkView.drawableSize.width, height: self.mtkView.drawableSize.height)
        self.view.insertSubview(self.mtkView, at: 0)

        // 创建纹理缓存区
        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.textureCache)
    }
    
    private func customInit() {
        self.setupCaptureSession()
        self.setupPipeline()
        self.setupVertices()
        self.setupDestTexture()
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
        let quadVertices = [ // 顶点坐标                                             纹理坐标
            SYVertex(position: [ 1.0, -1.0, 0.0, 1.0], textureCoordinate: [1.0, 1.0]), // 右下
            SYVertex(position: [-1.0, -1.0, 0.0, 1.0], textureCoordinate: [0.0, 1.0]), // 左下
            SYVertex(position: [-1.0,  1.0, 0.0, 1.0], textureCoordinate: [0.0, 0.0]), // 左上

            SYVertex(position: [ 1.0, -1.0, 0.0, 1.0], textureCoordinate: [1.0, 1.0]), // 右下
            SYVertex(position: [-1.0,  1.0, 0.0, 1.0], textureCoordinate: [0.0, 0.0]), // 左上
            SYVertex(position: [ 1.0,  1.0, 0.0, 1.0], textureCoordinate: [1.0, 0.0]), // 右上
        ]
        // 创建顶点数据缓存
        self.vertices = self.device.makeBuffer(bytes: quadVertices,
                                               length: MemoryLayout<SYVertex>.size * quadVertices.count,
                                               options: .storageModeShared)
        self.numVertices = quadVertices.count
    }
    
    // MARK: 设置结果纹理
    private func setupDestTexture() {
        let desciptor         = MTLTextureDescriptor()
        desciptor.pixelFormat = .bgra8Unorm // 格式要和相机数据一直
        desciptor.width       = Int(self.viewportSize.width)    // 纹理-宽度
        desciptor.height      = Int(self.viewportSize.height)   // 纹理-高度
        desciptor.usage       = MTLTextureUsage(rawValue: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue) // 目标纹理在 compute 管线需要写入，在 render 管线需要读取
        self.destTexture      = self.device.makeTexture(descriptor: desciptor)
    }
    
    // MARK: 设置线程组
    private func setupThreadGroup() {
        let width              = self.computePipeline.threadExecutionWidth
        let height             = self.computePipeline.maxTotalThreadsPerThreadgroup / width
        self.groupSize         = MTLSize(width: width, height: height, depth: 1)
        self.groupCount.width  = (Int(self.viewportSize.width)  + self.groupSize.width  - 1) / self.groupSize.width     // 确保每个像素都处理到
        self.groupCount.height = (Int(self.viewportSize.height) + self.groupSize.height - 1) / self.groupSize.height    // 确保每个像素都处理到
        self.groupCount.depth  = 1  // 2D 纹理，深度值为 1
    }
    
    // MARK: 设置视频录制
    private func setupCaptureSession() {
        self.captureSession               = AVCaptureSession()
        self.captureSession.sessionPreset = .hd1920x1080
        var inputCamera: AVCaptureDevice!
        let devSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],   // 常规镜头（广角镜头）
                                                          mediaType: .video,
                                                          position: .back)
        for dev in devSession.devices {
            if .back == dev.position {
                inputCamera = dev
                break
            }
        }
        if nil == inputCamera {
            print("Can not find back camera.")
            return
        }
        // 相机输入
        self.captureInput = try! AVCaptureDeviceInput(device: inputCamera!)
        if self.captureSession.canAddInput(self.captureInput) {
            self.captureSession.addInput(self.captureInput)
        }
        // 视频输出
        self.captureOutput = AVCaptureVideoDataOutput()
        // 设置视频帧延迟到底时是否丢弃数据（NO，有更多时间处理，但会增加内存）
        self.captureOutput.alwaysDiscardsLateVideoFrames = false
        // 这里设置为 BGRA 而不用 YUV 颜色空间，避免使用 Shader 转换
        self.captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
        // 设置相机会话代理
        self.captureOutput.setSampleBufferDelegate(self, queue: self.processQueue)
    
        if self.captureSession.canAddOutput(self.captureOutput) {
            self.captureSession.addOutput(self.captureOutput)
        }
        if let connection = self.captureOutput.connection(with: .video) {
            connection.videoOrientation = .portrait    // 设置相机方向
        }
        self.captureSession.startRunning()  // 启动相机
    }
}


extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportSize = CGSize(width: size.width, height: size.height)
    }
    
    func draw(in view: MTKView) {
        if nil == self.srcTexture {
            return
        }
        // 每次渲染都要单独创建一个 CommandBuffer
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("Create command buffer failure.")
            return
        }
        commandBuffer.label = "SY-command"
        // 内核计算出来
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.label = "SY-ComputeEncoder"
            // 设置内核计算管线（以调用 shaders.metal 中的内核计算函数）
            computeEncoder.setComputePipelineState(self.computePipeline)
            // 设置输入纹理
            computeEncoder.setTexture(self.srcTexture,
                                      index: Int(SYFragmentTextureIndexSrc.rawValue))
            self.srcTexture = nil
            // 设置输出纹理
            computeEncoder.setTexture(self.destTexture,
                                      index: Int(SYFragmentTextureIndexDest.rawValue))
            // 设置计算区域
            computeEncoder.dispatchThreadgroups(self.groupCount,
                                                threadsPerThreadgroup: self.groupSize)
            // 结束，释放编码器，下个 encoder 才能创建
            computeEncoder.endEncoding()
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


extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelbuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Get pixelbuffer failure.")
            return
        }
        CVPixelBufferLockBaseAddress(pixelbuffer, .readOnly)
        
        let width  = CVPixelBufferGetWidth(pixelbuffer)
        let height = CVPixelBufferGetHeight(pixelbuffer)
        
        var tmpTexture: CVMetalTexture?
        // 如果 MTLPixelFormat.rgba8Unorm 和摄像头采集时设置的颜色格式不一致，则会出现图像异常的情况；
        let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               self.textureCache,
                                                               pixelbuffer,
                                                               nil,
                                                               .bgra8Unorm,
                                                               width,
                                                               height,
                                                               0,
                                                               &tmpTexture)
        if kCVReturnSuccess == status {
            // 设置可绘制纹理的当前大小。
            self.mtkView.drawableSize = CGSize(width: width, height: height)
            // 返回纹理缓冲区的 Metal 纹理对象。
            self.srcTexture = CVMetalTextureGetTexture(tmpTexture!)
        }
        
        CVPixelBufferUnlockBaseAddress(pixelbuffer, .readOnly)
    }
}

