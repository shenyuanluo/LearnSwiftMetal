//
//  ViewController.swift
//  04_ComputeGray
//
//  Created by ShenYuanLuo on 2022/5/12.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    private var mtkView: MTKView!                           // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                          // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!              // 命令队列（控制渲染命令按部就班执行）
    private var renderPipeline: MTLRenderPipelineState!     // 图形渲染管线
    private var computePipeline: MTLComputePipelineState!   // 内核计算管线
    private var vertices: MTLBuffer!                        // 顶点数据缓存
    private var numVertices: Int = 0                        // 顶点数量
    private var srcTexture: MTLTexture!                     // 原始-纹理对象
    private var destTexture: MTLTexture!                    // 目的-纹理对象
    private var groupSize: MTLSize!                         // 每个线程大小
    private var groupCount: MTLSize = MTLSize()             // 线程组数
    private var viewportSize = CGSize(width: 0, height: 0)  // 当前视图大小

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
        
        self.customInit()
    }
    
    // MARK: 初始化
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
        guard let computeGrayFun = library.makeFunction(name: "ComputeGray") else {
            return
        }
        // 渲染管线描述符
        let descriptor                             = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction                  = vertexFun
        descriptor.fragmentFunction                = fragmentFun
        descriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat
        // 创建图形渲染管线（耗性能，不宜频繁操作）
        self.renderPipeline = try! self.device.makeRenderPipelineState(descriptor: descriptor)
        // 创建内核计算管线（耗性能，不宜频繁操作）
        self.computePipeline = try! self.device.makeComputePipelineState(function: computeGrayFun)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()
    }

    // MARK: 设置顶点数据缓存
    private func setupVertices() {
        let viewWidth    = Float(self.viewportSize.width)
        let viewHeight   = Float(self.viewportSize.height)
        let quadVertices = [ // 顶点坐标                                                            纹理坐标
            SYVertex(position: [ 0.5, -0.5 / viewHeight * viewWidth, 0.0, 1.0], textureCoordinate: [1.0, 1.0]),
            SYVertex(position: [-0.5, -0.5 / viewHeight * viewWidth, 0.0, 1.0], textureCoordinate: [0.0, 1.0]),
            SYVertex(position: [-0.5,  0.5 / viewHeight * viewWidth, 0.0, 1.0], textureCoordinate: [0.0, 0.0]),
            
            SYVertex(position: [ 0.5, -0.5 / viewHeight * viewWidth, 0.0, 1.0], textureCoordinate: [1.0, 1.0]),
            SYVertex(position: [-0.5,  0.5 / viewHeight * viewWidth, 0.0, 1.0], textureCoordinate: [0.0, 0.0]),
            SYVertex(position: [ 0.5,  0.5 / viewHeight * viewWidth, 0.0, 1.0], textureCoordinate: [1.0, 0.0]),
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
        descriptor.usage       = .shaderRead    // 原始纹理只需「读」权限
        self.srcTexture        = self.device.makeTexture(descriptor: descriptor)    // 创建纹理
        // 纹理上传范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(img.size.width), height: Int(img.size.height), depth: 1))
        // UIImage 的数据需要转成二进制才能上传，且不用 jpg、png 的 NSData
        guard let data = self.loadImage(img) else {
            print("Load image data failure.")
            return
        }
        // 拷贝图像数据到纹理
        self.srcTexture.replace(region: region,
                             mipmapLevel: 0,
                             withBytes: data,
                             bytesPerRow: Int(img.size.width) * 4)
        // 目的纹理需要「读|写」权限
        descriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue)
        self.destTexture = self.device.makeTexture(descriptor: descriptor)
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
    
    private func setupThreadGroup() {
        self.groupSize = MTLSizeMake(16, 16, 1) // 每次处理的大小（太大某些 GPU 不支持，大小效率低）
        // 保证每个像素都有处理到
        self.groupCount.width  = (self.srcTexture.width  + self.groupSize.width - 1) / self.groupSize.width
        self.groupCount.height = (self.srcTexture.height + self.groupSize.height - 1) / self.groupSize.height
        self.groupCount.depth  = 1   // 2D 纹理，深度为 1
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
        
        // 创建计算指令编码器
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.label = "SY-ComputeEncoder"
            // 设置「计算」管线，已调用 shaders.metal 中的内核计算函数
            computeEncoder.setComputePipelineState(self.computePipeline)
            // 设置「输入」纹理
            computeEncoder.setTexture(self.srcTexture,
                                      index: Int(SYFragmentInputIndexTextureSrc.rawValue))
            // 设置「输出」纹理
            computeEncoder.setTexture(self.destTexture,
                                      index: Int(SYFragmentInputIndexTextureDest.rawValue))
            // 设置计算区域
            computeEncoder.dispatchThreadgroups(self.groupCount,
                                                threadsPerThreadgroup: self.groupSize)
            // 调用 endEncoding 以释放编码器（这样下个 encoder 才可以创建）
            computeEncoder.endEncoding()
        }
        
        // MTLRenderPassDescriptor 描述一系列 attachments 的值，类似 OpenGL 的 FrameBuffer；同时也用来创建 MTLRenderCommandEncoder
        if let descriptor = view.currentRenderPassDescriptor {
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
                renderEncoder.setFragmentTexture(self.destTexture,
                                                 index: 0)
                // 开始绘制
                renderEncoder.drawPrimitives(type: .triangle,
                                             vertexStart: 0,
                                             vertexCount: self.numVertices)
                renderEncoder.endEncoding() // 结束
            }
            commandBuffer.present(view.currentDrawable!)    // 显示
        }
        commandBuffer.commit()  // 提交
    }
}

