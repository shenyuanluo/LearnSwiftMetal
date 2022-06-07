//
//  ViewController.swift
//  LearnSwiftMetal
//
//  Created by ShenYuanLuo on 2022/4/29.
//

import UIKit
import MetalKit
import simd

class ViewController: UIViewController {
    private var mtkView: MTKView!                               // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                              // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!                  // 命令队列（控制渲染命令按部就班执行）
    private var pipelineState: MTLRenderPipelineState!          // 图形渲染管道
    private var vertices: MTLBuffer!                            // 顶点数据缓冲
    private var numVertices: Int = 0                            // 顶点数量
    private var texture: MTLTexture!                            // 纹理对象
    private var viewportSize: vector_uint2 = vector_uint2(0, 0) // 当前视图大小

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mtkView        = MTKView(frame: self.view.bounds)
        self.mtkView.device = MTLCreateSystemDefaultDevice()
        if nil == self.mtkView.device {
            print("Metal is not support on this device.")
            return
        }
        self.device           = self.mtkView.device
        self.view             = self.mtkView
        self.mtkView.delegate = self
        self.viewportSize.x   = UInt32(self.mtkView.drawableSize.width)
        self.viewportSize.y   = UInt32(self.mtkView.drawableSize.height)
        
        self.customInit()
    }

    private func customInit() {
        self.setupPipeline()
        self.setupVertex()
        self.setupTexture()
    }
    
    // MARK: 设置渲染管线
    private func setupPipeline() {
        // 加载所有的着色器文件（.metal）
        guard let library = self.device.makeDefaultLibrary() else {    // 从 Bundle 中获取 .metal 文件
            print("Can not create (.metal) library.")
            return
        }
        guard let vertexFun = library.makeFunction(name: "VertexShader") else { // 加载顶点着色器（VertexShader 是函数名称）
            print("Can not create vertex shader.")
            return
        }
        guard let fragmentFun = library.makeFunction(name: "FragmentShader") else { // 加载片段着色器（FragmentShader 是函数名称）
            print("Can not create fragment shader.")
            return
        }
        // 配置渲染管道
        let descriptor                             = MTLRenderPipelineDescriptor()
        descriptor.label                           = "SY-Pipeline"
        descriptor.vertexFunction                  = vertexFun
        descriptor.fragmentFunction                = fragmentFun
        descriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat
        // 创建图形渲染管线（耗性能操作不宜频繁调用）
        self.pipelineState = try! self.device.makeRenderPipelineState(descriptor: descriptor)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue  = self.device.makeCommandQueue()
    }
    
    // MARK: 设置顶点数据缓冲
    private func setupVertex() {    // 矩形顶点
        let quadVertices = [
            // 第一个三角形
            SYVertex(position: vector_float4(  0.5, -0.5, 0.0, 1.0 ), textureCoordinate: vector_float2(1.0, 1.0 )),
            SYVertex(position: vector_float4( -0.5, -0.5, 0.0, 1.0 ), textureCoordinate: vector_float2(0.0, 1.0 )),
            SYVertex(position: vector_float4( -0.5,  0.5, 0.0, 1.0 ), textureCoordinate: vector_float2(0.0, 0.0 )),
            // 第二个三角形
            SYVertex(position: vector_float4(  0.5, -0.5, 0.0, 1.0 ), textureCoordinate: vector_float2(1.0, 1.0 )),
            SYVertex(position: vector_float4( -0.5,  0.5, 0.0, 1.0 ), textureCoordinate: vector_float2(0.0, 0.0 )),
            SYVertex(position: vector_float4(  0.5,  0.5, 0.0, 1.0 ), textureCoordinate: vector_float2(1.0, 0.0 )),
        ]
        self.numVertices = quadVertices.count   // 顶点个数
        // 创建顶点缓存
        self.vertices = self.device.makeBuffer(bytes: quadVertices,
                                               length: MemoryLayout<SYVertex>.size * self.numVertices,
                                               options: .storageModeShared)
    }
    
    // 设置文件里
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
        descriptor.pixelFormat = .rgba8Unorm    // 像素格式（RGBA）
        descriptor.width       = Int(img.size.width)    // 纹理-宽度
        descriptor.height      = Int(img.size.height)   // 纹理-高度
        self.texture           = self.device.makeTexture(descriptor: descriptor)   // 创建纹理
        // 纹理上传的范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(img.size.width), height: Int(img.size.height), depth: 1))
        // UIImage 的数据需要转成二进制才能上传，且不用 jpg、png 的 NSData
        guard let data = UIImage.loadImage(img) else {
            print("Load image data failure.")
            return
        }
        self.texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: Int(img.size.width) * 4)
    }

}


// MARK: - MTKViewDelegate
extension ViewController: MTKViewDelegate {
    // 每当视图改变方向或调整大小时调用
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportSize = vector_uint2(x: UInt32(size.width), y: UInt32(size.height))
    }
    
    // 每当视图需要渲染帧时调用
    func draw(in view: MTKView) {
        // 每次渲染都要单独创建一个 CommandBuffer
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("创建 CMD 缓冲失败")
            return
        }
        commandBuffer.label = "SY-Command"
        // MTLRenderPassDescriptor 描述一系列 attachments 的值，类似 OpenGL 的 FrameBuffer；同时也用来创建 MTLRenderCommandEncoder
        if let descriptor = view.currentRenderPassDescriptor {
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0)  // 设置默认颜色
            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
                renderEncoder.label = "SY-RenderEncoder"
                renderEncoder.setViewport(MTLViewport(originX: 0,
                                                       originY: 0,
                                                       width: Double(self.viewportSize.x),
                                                       height: Double(self.viewportSize.y),
                                                       znear: -1.0,
                                                       zfar: 1.0))  // 设置显示区域
                renderEncoder.setRenderPipelineState(self.pipelineState)    // 设置渲染管道（以保证「顶点」和「片段」两个 shader 会被调用）
                renderEncoder.setVertexBuffer(self.vertices, offset: 0, index: 0)   // 设置顶点缓存
                renderEncoder.setFragmentTexture(self.texture, index: 0)    // 设置纹理
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: self.numVertices)    // 绘制
                renderEncoder.endEncoding() // 结束
            }
            commandBuffer.present(view.currentDrawable!)    // 显示
        }
        commandBuffer.commit()  // 提交
    }
}

