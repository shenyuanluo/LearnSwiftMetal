//
//  ViewController.swift
//  11_HistogramEqualization
//
//  Created by ShenYuanLuo on 2022/5/30.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    private var mtkView: MTKView!                               // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                              // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!                  // 命令队列（控制渲染命令按部就班执行）
    private var renderPipeline: MTLRenderPipelineState!         // 图形渲染管线
    private var computePipeline: MTLComputePipelineState!       // 内核计算管线
    private var vertices: MTLBuffer!                            // 顶点数据缓存
    private var colorBuffer: MTLBuffer!                         // 统计颜色缓存
    private var convertBuffer: MTLBuffer!                       // 转换颜色缓存
    private var numVertices: Int = 0                            // 顶点数量
    private var sourceTexture: MTLTexture!                      // 纹理对象
    private var viewportSize = CGSize(width: 0, height: 0)      // 当前视图大小
    private var groupSize: MTLSize = MTLSize(width: 16, height: 16, depth: 1)   // 每线程组线程大小（内核计算）
    private var groupCount: MTLSize = MTLSize(width: 16, height: 16, depth: 1)  // 每网格线程组大小（内核计算）
    
    private lazy var originImagV: UIImageView = {
        let rect = CGRect(x: 10, y: 40, width: self.view.bounds.width / 2 - 20, height: self.view.bounds.width / 2 - 20)
        let view = UIImageView(frame: rect)
        return view
    }()
    private lazy var convertImagV: UIImageView = {
        let rect = CGRect(x: self.view.bounds.width / 2 + 10, y: 40, width: self.view.bounds.width / 2 - 20, height: self.view.bounds.width / 2 - 20)
        let view = UIImageView(frame: rect)
        return view
    }()
    
    // SYLocalBuffer() Swift 默认将 C fixed-size array 转为 tuple，
    // Swift 中对元组的「读写」不是很友好，因此直接使用「二维数组」
    private var cpuColorBuffer: [[Int32]] = Array<Array<Int32>>(repeating: Array<Int32>(repeating: 0, count: Int(SY_CHANNEL_SIZE)),
                                                                count: Int(SY_CHANNEL_NUM))
    private var isDrawing: Bool = false // 是否正在绘制（毕淼多次 compute 的影响）

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
        self.viewportSize     = CGSize(width: self.mtkView.drawableSize.width,
                                       height: self.mtkView.drawableSize.height)
        self.view.insertSubview(self.mtkView, at: 0)

        self.configUI()
        self.customInit()
    }
    
    private func configUI() {
        self.view.addSubview(self.originImagV)
        self.view.addSubview(self.convertImagV)
    }

    private func customInit() {
        self.setupPipeline()
        self.setupVertex()
        self.setupTexture()
        self.setupBuffer()
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
        // 内核计算处理
        guard let grayComputeFun = library.makeFunction(name: "GrayCompute") else {
            print("Can not create gray compute func.")
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
        self.computePipeline = try! self.device.makeComputePipelineState(function: grayComputeFun)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()
    }
    
    // MARk: 设置顶点
    private func setupVertex() {
        let quadVertices: [SYVertex] = [
            // 第一个三角形
            SYVertex(position: [ 0.5, -0.5 / Float(self.viewportSize.height) * Float(self.viewportSize.width), 0.0, 1.0], textureCoordinate: [1.0, 1.0]),   // 右下
            SYVertex(position: [-0.5, -0.5 / Float(self.viewportSize.height) * Float(self.viewportSize.width), 0.0, 1.0], textureCoordinate: [0.0, 1.0]),   // 左下
            SYVertex(position: [-0.5,  0.5 / Float(self.viewportSize.height) * Float(self.viewportSize.width), 0.0, 1.0], textureCoordinate: [0.0, 0.0]),   // 左上
            // 第二个三角形
            SYVertex(position: [ 0.5, -0.5 / Float(self.viewportSize.height) * Float(self.viewportSize.width), 0.0, 1.0], textureCoordinate: [1.0, 1.0]),   // 右下
            SYVertex(position: [-0.5,  0.5 / Float(self.viewportSize.height) * Float(self.viewportSize.width), 0.0, 1.0], textureCoordinate: [0.0, 0.0]),   // 左上
            SYVertex(position: [ 0.5,  0.5 / Float(self.viewportSize.height) * Float(self.viewportSize.width), 0.0, 1.0], textureCoordinate: [1.0, 0.0]),   // 右上
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
        let file       = bundle.path(forResource: "Elephant", ofType: "jpeg") else {
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
        descriptor.usage       = .shaderRead
        self.sourceTexture     = self.device.makeTexture(descriptor: descriptor)    // 创建纹理
        // 纹理上传范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(img.size.width), height: Int(img.size.height), depth: 1))
        // UIImage 的数据需要转成二进制才能上传，且不用 jpg、png 的 NSData
        guard let data = UIImage.loadImage(img) else {
            print("Load image data failure.")
            return
        }
        // 拷贝图像数据到纹理
        self.sourceTexture.replace(region: region,
                                   mipmapLevel: 0,
                                   withBytes: data,
                                   bytesPerRow: Int(img.size.width) * 4)
        // 原始 image
        self.originImagV.image = img
        // CPU 转换 image
        self.convertImagV.image = self.cpuConvert(image: img)
    }
    
    // MARK: CPU 转换
    private func cpuConvert(image: UIImage) -> UIImage? {
        // 获取图片的 CGImage
        guard let spriteImage = image.cgImage else { return nil }
        // 读取图片大小
        let width  = spriteImage.width
        let height = spriteImage.height
        let data   = UnsafeMutableRawPointer.allocate(byteCount: width * height * 4, alignment: 8)
        
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        
        // 创建画布
        guard let context = CGContext(data: data,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: spriteImage.colorSpace!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            print("Failed to create CG context.")
            UIGraphicsEndImageContext()
            return nil
        }
        // 在 context 上绘图
        context.draw(spriteImage, in: CGRect(x: 0, y: 0, width: width, height: height), byTiling: true)    // 在画布上绘制
        
        let pixelCount = Int(width * height)    // 总像素点数
        // CPU 进行统计
        for i in 0..<pixelCount {  // 遍历所有像素点
            for j in 0..<Int(SY_CHANNEL_NUM) {  // 遍历每个 RGB 通道值
                let c: UInt8 = data.load(fromByteOffset: i * 4 + j, as: UInt8.self) // 原始图片像素有 RGBA 4 个通道
                self.cpuColorBuffer[j][Int(c)] += 1 // 统计当前像素点对应通道的值（统计直方图）
            }
        }
#if DEBUG
        // 打印统计结果
        for i in 0..<Int(SY_CHANNEL_NUM) {
            for j in 0..<Int(SY_CHANNEL_SIZE) {
                print("\(self.cpuColorBuffer[i][j]) ", terminator: "")
            }
            print("\n------")
        }
#endif
        var rgb = Array<Array<Int32>>(repeating: Array<Int32>(repeating: 0, count: Int(SY_CHANNEL_SIZE)),
                                      count: Int(SY_CHANNEL_NUM)) // rgb[3][256]
        var val = Array<Int32>(repeating: 0, count: Int(SY_CHANNEL_NUM))    // val[3]
        // 颜色映射
        for i in 0..<Int(SY_CHANNEL_NUM) {
            for j in 0..<Int(SY_CHANNEL_SIZE) {
                val[i]   += self.cpuColorBuffer[i][j]   // （累计直方图）
                rgb[i][j] = Int32(Float(val[i]) * Float(SY_CHANNEL_SIZE - 1) / Float(pixelCount))   // 累计直方图（百分比）
            }
        }
        
        // 图片像素值修改
        for i in 0..<pixelCount {
            for j in 0..<Int(SY_CHANNEL_NUM) {
                let offset = i * 4 + Int(j)
                let c      = data.load(fromByteOffset: offset, as: UInt8.self)
                let value  = UInt8(rgb[j][Int(c)])
                data.storeBytes(of: value, toByteOffset: offset, as: UInt8.self)
            }
        }
        
        if let convertCGImage = context.makeImage() {
            let convertImage = UIImage(cgImage: convertCGImage)
            UIGraphicsEndImageContext()
            return convertImage
        }
        UIGraphicsEndImageContext()
        return nil
    }
    
    // MARK: 设置缓存
    private func setupBuffer() {
        // 申请颜色统计缓存（用于内核计算统函数计）
        self.colorBuffer = self.device.makeBuffer(length: MemoryLayout<SYLocalBuffer>.size,
                                                  options: .storageModeShared)
        // 申请颜色转换缓存（用于片段着色器转换颜色）
        self.convertBuffer = self.device.makeBuffer(length: MemoryLayout<SYLocalBuffer>.size,
                                                    options: .storageModeShared)
    }
    
    // MARK: 设置线程组
    private func setupThreadGroup() {
        let width              = self.computePipeline.threadExecutionWidth
        let height             = self.computePipeline.maxTotalThreadsPerThreadgroup / width
        self.groupSize         = MTLSize(width: width, height: height, depth: 1)
        self.groupCount.width  = (self.sourceTexture.width  + self.groupSize.width  - 1) / self.groupSize.width     // 确保每个像素都处理到
        self.groupCount.height = (self.sourceTexture.height + self.groupSize.height - 1) / self.groupSize.height    // 确保每个像素都处理到
        self.groupCount.depth  = 1  // 2D 纹理，深度值为 1
    }
    
    // 绘制
    private func customDraw() {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("Create command buffer failure.")
            return
        }
        commandBuffer.label = "SY-command"
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.label = "SY-compute"
            // 设置内核计算管线（以调用内核计算函数）
            computeEncoder.setComputePipelineState(self.computePipeline)
            // 设置输入纹理
            computeEncoder.setTexture(self.sourceTexture,
                                      index: Int(SYKernelTextureIndexSource.rawValue))
            // 设置统计结果缓存
            computeEncoder.setBuffer(self.colorBuffer,
                                     offset: 0,
                                     index: Int(SYKernelBufferIndexOutput.rawValue))
            // 计算区域
            computeEncoder.dispatchThreadgroups(self.groupCount,
                                                threadsPerThreadgroup: self.groupSize)
            // 结束编码（释放编码器，下个编码器才能创建）
            computeEncoder.endEncoding()
        }
        commandBuffer.addCompletedHandler { [weak self] buffer in
            guard let self = self else { return }
            let colorPtr   = self.colorBuffer.contents()   // GPU 统计结果
            let convertPtr = self.convertBuffer.contents() // 颜色转换结果
            let sum        = Int32(self.sourceTexture.width * self.sourceTexture.height)  // 总像素点
            var val        = Array<Int32>(repeating: 0, count: 3)    // 累计和
            for i in 0..<Int(SY_CHANNEL_NUM) {
                for j in 0..<Int(SY_CHANNEL_SIZE) {
                    let offset = MemoryLayout<Int32>.size * (i * Int(SY_CHANNEL_SIZE) + j)
                    val[i]    += colorPtr.load(fromByteOffset: offset, as: Int32.self)    // 当前 [0, j] 累计出现的总次数
                    convertPtr.storeBytes(of: Int32(Float(val[i]) * Float(SY_CHANNEL_SIZE - 1) / Float(sum)),
                                          toByteOffset: offset,
                                          as: Int32.self)
                    let gpuValue = colorPtr.load(fromByteOffset: offset, as: Int32.self)
                    let cpuValue = self.cpuColorBuffer[i][j]
                    // 对比 CPU 和 GPU 处理的结果
                    if gpuValue != cpuValue {   // 如果不同，把对应的结果输出
                        print("\(i), \(j), GPU: \(gpuValue), CPU: \(cpuValue)")
                    }
                }
            }
            memset(colorPtr, 0, self.colorBuffer.length)
            self.renderNewImage()
        }
        commandBuffer.commit()  // 提交
    }
    
    // MARK: 绘制下一帧
    private func renderNewImage() {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("Create command buffer failure.")
            return
        }
        // MTLRenderPassDescriptor 描述一系列 attachments 的值，类似 OpenGL 的 FrameBuffer；同时也用来创建 MTLRenderCommandEncoder
        if let descriptor = self.mtkView.currentRenderPassDescriptor {
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
                                              index: Int(SYVertexBufferIndexVertices.rawValue))
                // 设置纹理
                renderEncoder.setFragmentTexture(self.sourceTexture,
                                                 index: Int(SYFragmentTextureIndexSource.rawValue))
                // 设置转换缓存
                renderEncoder.setFragmentBuffer(self.convertBuffer,
                                                offset: 0,
                                                index: Int(SYFragmentBufferIndexConvert.rawValue))
                // 开始绘制
                renderEncoder.drawPrimitives(type: .triangle,
                                             vertexStart: 0,
                                             vertexCount: self.numVertices)
                renderEncoder.endEncoding() // 结束
            }
            commandBuffer.present(self.mtkView.currentDrawable!)    // 显示
        }
        commandBuffer.commit()  // 提交
        self.isDrawing = false
    }
}


extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportSize = CGSize(width: size.width, height: size.height)
    }
    
    func draw(in view: MTKView) {
        if false == self.isDrawing {
            self.isDrawing = true
            self.customDraw()
        }
    }
}
