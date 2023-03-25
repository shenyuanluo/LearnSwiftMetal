//
//  ViewController.swift
//  Sec14_HexagonMosaic
//
//  Created by ShenYuanLuo on 2022/6/9.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    private var mtkView: MTKView!                               // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                              // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!                  // 命令队列（控制渲染命令按部就班执行）
    private var renderPipeline: MTLRenderPipelineState!         // 图形渲染管线
    private var normalTexture: MTLTexture!                      // 纹理对象
    private var vertices: MTLBuffer!                            // 顶点数据缓存
    private var numVertices: Int = 0                            // 顶点数量
    private var viewportSize = vector_uint2(0, 0)               // 当前视图大小
    
    private lazy var normalImgV: UIImageView = {
        let rect = CGRect(x: self.view.bounds.width / 4, y: 40, width: self.view.bounds.width / 2, height: self.view.bounds.width / 2)
        let imgv = UIImageView(frame: rect)
        return imgv
    }()
    

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
        
        self.customInit()
        
        self.view.addSubview(self.normalImgV)
    }

    private func customInit() {
        self.setupPipeline()
        self.setupVertex()
        self.setupTexture()
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
            SYVertex(position: [ 0.5, -0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [1.0, 1.0]),   // 右下
            SYVertex(position: [-0.5, -0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [0.0, 1.0]),   // 左下
            SYVertex(position: [-0.5,  0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [0.0, 0.0]),   // 左上
            // 第二个三角形
            SYVertex(position: [ 0.5, -0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [1.0, 1.0]),   // 右下
            SYVertex(position: [-0.5,  0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [0.0, 0.0]),   // 左上
            SYVertex(position: [ 0.5,  0.5 / Float(self.viewportSize.y) * Float(self.viewportSize.x), 0.0, 1.0], textureCoordinate: [1.0, 0.0]),   // 右上
        ];
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
            print("Can not find normal image file.")
            return
        }
        guard let img = UIImage(contentsOfFile: file) else {
            print("Load normal image file failure.")
            return
        }
        // 纹理描述符
        let descriptor         = MTLTextureDescriptor()
        descriptor.pixelFormat = .rgba8Unorm            // 像素格式（RGBA）
        descriptor.width       = Int(img.size.width)    // 纹理-宽度
        descriptor.height      = Int(img.size.height)   // 纹理-高度
        descriptor.usage       = .shaderRead
        self.normalTexture     = self.device.makeTexture(descriptor: descriptor)    // 创建纹理
        // 纹理上传范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(img.size.width), height: Int(img.size.height), depth: 1))
        // UIImage 的数据需要转成二进制才能上传，且不用 jpg、png 的 NSData
        guard let data = UIImage.loadImage(img) else {
            print("Load image data failure.")
            return
        }
        // 拷贝图像数据到纹理
        self.normalTexture.replace(region: region,
                                   mipmapLevel: 0,
                                   withBytes: data,
                                   bytesPerRow: Int(img.size.width) * 4)
        // 原始 image
        self.normalImgV.image = img
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
            renderEncoder.setFragmentTexture(self.normalTexture,
                                             index: Int(SYFragmentInputIndexTexture.rawValue))
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
