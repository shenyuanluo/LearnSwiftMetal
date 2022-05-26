//
//  ViewController.swift
//  09_SkyBox2D
//
//  Created by ShenYuanLuo on 2022/5/26.
//

import UIKit
import MetalKit
import GLKit

class ViewController: UIViewController {
    private var mtkView: MTKView!                               // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                              // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!                  // 命令队列（控制渲染命令按部就班执行）
    private var pipelineState: MTLRenderPipelineState!          // 图形渲染管线
    private var vertices: MTLBuffer!                            // 顶点数据缓存
    private var indices: MTLBuffer!                             // 索引数据缓存
    private var numVertices: Int = 0                            // 顶点数量
    private var numIndices: Int = 0                             // 索引数量
    private var texture: MTLTexture!                            // 纹理对象
    private var viewportSize: vector_uint2 = vector_uint2(0, 0) // 当前视图大小
    
    private var eyePosition = GLKVector3Make(0, 0, 0)           // 眼睛位置
    private var lookAtPosition = GLKVector3Make(0, 0, 0)        // 观察位置
    private var upVector = GLKVector3Make(0, 1, 0)              // 向上向量
    
    private var angleEye: Float = 0
    private var angleLook: Float = 0
    
    private lazy var eyeLabel: UILabel = {
        let label  = UILabel(frame: CGRect(x: 20, y: 100, width: 80, height: 40))
        label.text = "眼睛："
        return label
    }()
    private lazy var eyeSwitch: UISwitch = {
        let view  = UISwitch(frame: CGRect(x: 100, y: 100, width: 120, height: 40))
        view.isOn = false
        return view
    }()
    private lazy var lookAtLabel: UILabel = {
        let label  = UILabel(frame: CGRect(x: 20, y: 150, width: 80, height: 40))
        label.text = "朝向："
        return label
    }()
    private lazy var lookAtSwitch: UISwitch = {
        let view  = UISwitch(frame: CGRect(x: 100, y: 150, width: 120, height: 40))
        view.isOn = false
        return view
    }()
    private lazy var rotateLabel: UILabel = {
        let label  = UILabel(frame: CGRect(x: 240, y: 90, width: 80, height: 40))
        label.text = "旋转速率"
        return label
    }()
    private lazy var rotateSlider: UISlider = {
        let slider          = UISlider(frame: CGRect(x: 180, y: 120, width: 150, height: 40))
        slider.maximumValue = 0.02
        slider.minimumValue = 0.002
        slider.value        = 0.01
        return slider
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
        self.viewportSize     = vector_uint2(x: UInt32(self.mtkView.drawableSize.width),
                                             y: UInt32(self.mtkView.drawableSize.height))
        self.view.insertSubview(self.mtkView, at: 0)
        
        self.configUI()
        
        self.customInit()
    }
    
    private func configUI() {
        self.view.addSubview(self.eyeLabel)
        self.view.addSubview(self.eyeSwitch)
        self.view.addSubview(self.lookAtLabel)
        self.view.addSubview(self.lookAtSwitch)
        self.view.addSubview(self.rotateLabel)
        self.view.addSubview(self.rotateSlider)
    }

    private func customInit() {
        self.setupPipeline()
        self.setupVertex()
        self.setupTexture()
    }
    
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
        self.pipelineState = try! self.device.makeRenderPipelineState(descriptor: descriptor)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()
    }
    
    // MARk: 设置顶点
    private func setupVertex() {
        let quadVertices: [SYVertex] = [
            // 上面
            SYVertex(position: [-6.0,  6.0, 6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [0.0, 2.0/6]),    // 左上 0
            SYVertex(position: [-6.0, -6.0, 6.0, 1.0], color: [0.0, 0.0, 1.0], textureCoordinate: [0.0, 3.0/6]),    // 左下 2
            SYVertex(position: [ 6.0, -6.0, 6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [1.0, 3.0/6]),    // 右下 3

            SYVertex(position: [-6.0,  6.0, 6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [0.0, 2.0/6]),    // 左上 0
            SYVertex(position: [ 6.0,  6.0, 6.0, 1.0], color: [0.0, 1.0, 0.0], textureCoordinate: [1.0, 2.0/6]),    // 右上 1
            SYVertex(position: [ 6.0, -6.0, 6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [1.0, 3.0/6]),    // 右下 3

            
            // 下面
            SYVertex(position: [-6.0,  6.0, -6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [0.0, 4.0/6]),    // 左上 4
            SYVertex(position: [ 6.0,  6.0, -6.0, 1.0], color: [0.0, 1.0, 0.0], textureCoordinate: [1.0, 4.0/6]),    // 右上 5
            SYVertex(position: [ 6.0, -6.0, -6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [1.0, 3.0/6]),    // 右下 7

            SYVertex(position: [-6.0,  6.0, -6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [0.0, 4.0/6]),    // 左上 4
            SYVertex(position: [-6.0, -6.0, -6.0, 1.0], color: [0.0, 0.0, 1.0], textureCoordinate: [0.0, 3.0/6]),    // 左下 6
            SYVertex(position: [ 6.0, -6.0, -6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [1.0, 3.0/6]),    // 右下 7
            
            
            // 左面
            SYVertex(position: [-6.0,  6.0, 6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [0.0, 1.0/6]),    // 左上 0
            SYVertex(position: [-6.0, -6.0, 6.0, 1.0], color: [0.0, 0.0, 1.0], textureCoordinate: [1.0, 1.0/6]),    // 左下 2
            SYVertex(position: [-6.0, 6.0, -6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [0.0, 2.0/6]),    // 左上 4

            SYVertex(position: [-6.0, -6.0,  6.0, 1.0], color: [0.0, 0.0, 1.0], textureCoordinate: [1.0, 1.0/6]),   // 左下 2
            SYVertex(position: [-6.0,  6.0, -6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [0.0, 2.0/6]),   // 左上 4
            SYVertex(position: [-6.0, -6.0, -6.0, 1.0], color: [0.0, 0.0, 1.0], textureCoordinate: [1.0, 2.0/6]),   // 左下 6


            // 右面
            SYVertex(position: [6.0,  6.0,  6.0, 1.0], color: [0.0, 1.0, 0.0], textureCoordinate: [1.0, 0.0/6]),    // 右上 1
            SYVertex(position: [6.0, -6.0,  6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [0.0, 0.0/6]),    // 右下 3
            SYVertex(position: [6.0,  6.0, -6.0, 1.0], color: [0.0, 1.0, 0.0], textureCoordinate: [1.0, 1.0/6]),    // 右上 5

            SYVertex(position: [6.0, -6.0,  6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [0.0, 0.0/6]),    // 右下 3
            SYVertex(position: [6.0,  6.0, -6.0, 1.0], color: [0.0, 1.0, 0.0], textureCoordinate: [1.0, 1.0/6]),    // 右上 5
            SYVertex(position: [6.0, -6.0, -6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [0.0, 1.0/6]),    // 右下 7
            
            
            // 前面
            SYVertex(position: [-6.0, -6.0,  6.0, 1.0], color: [0.0, 0.0, 1.0], textureCoordinate: [0.0, 4.0/6]),   // 左下 2
            SYVertex(position: [ 6.0, -6.0,  6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [1.0, 4.0/6]),   // 右下 3
            SYVertex(position: [ 6.0, -6.0, -6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [1.0, 5.0/6]),   // 右下 7

            SYVertex(position: [-6.0, -6.0,  6.0, 1.0], color: [0.0, 0.0, 1.0], textureCoordinate: [0.0, 4.0/6]),   // 左下 2
            SYVertex(position: [-6.0, -6.0, -6.0, 1.0], color: [0.0, 0.0, 1.0], textureCoordinate: [0.0, 5.0/6]),   // 左下 6
            SYVertex(position: [ 6.0, -6.0, -6.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [1.0, 5.0/6]),   // 右下 7

            
            // 后面
            SYVertex(position: [-6.0, 6.0,  6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [1.0, 5.0/6]),    // 左上 0
            SYVertex(position: [ 6.0, 6.0,  6.0, 1.0], color: [0.0, 1.0, 0.0], textureCoordinate: [0.0, 5.0/6]),    // 右上 1
            SYVertex(position: [ 6.0, 6.0, -6.0, 1.0], color: [0.0, 1.0, 0.0], textureCoordinate: [0.0, 6.0/6]),    // 右上 5

            SYVertex(position: [-6.0, 6.0,  6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [1.0, 5.0/6]),    // 左上 0
            SYVertex(position: [-6.0, 6.0, -6.0, 1.0], color: [1.0, 0.0, 0.0], textureCoordinate: [1.0, 6.0/6]),    // 左上 4
            SYVertex(position: [ 6.0, 6.0, -6.0, 1.0], color: [0.0, 1.0, 0.0], textureCoordinate: [0.0, 6.0/6]),    // 右上 5
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
        let file       = bundle.path(forResource: "SkyBox", ofType: "png") else {
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
        self.texture           = self.device.makeTexture(descriptor: descriptor)    // 创建纹理
        // 纹理上传范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(img.size.width), height: Int(img.size.height), depth: 1))
        // UIImage 的数据需要转成二进制才能上传，且不用 jpg、png 的 NSData
        guard let data = self.loadImage(img) else {
            print("Load image data failure.")
            return
        }
        // 拷贝图像数据到纹理
        self.texture.replace(region: region,
                             mipmapLevel: 0,
                             withBytes: data,
                             bytesPerRow: Int(img.size.width) * 4)
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
    
    // MARK: OpenGL 矩阵转 Metal 矩阵
    private func metalMatrix(form glMatrix: GLKMatrix4) -> matrix_float4x4 {
        let ret = matrix_float4x4(SIMD4(glMatrix.m00, glMatrix.m01, glMatrix.m02, glMatrix.m03),
                                  SIMD4(glMatrix.m10, glMatrix.m11, glMatrix.m12, glMatrix.m13),
                                  SIMD4(glMatrix.m20, glMatrix.m21, glMatrix.m22, glMatrix.m23),
                                  SIMD4(glMatrix.m30, glMatrix.m31, glMatrix.m32, glMatrix.m33))
        return ret
    }
    
    // 设置矩阵
    private func setupMatrixWith(encoder: MTLRenderCommandEncoder) {
        if self.eyeSwitch.isOn {
            self.angleEye += self.rotateSlider.value
        }
        if self.lookAtSwitch.isOn {
            self.angleLook += self.rotateSlider.value
        }
        
        // 调整眼睛位置
        self.eyePosition = GLKVector3Make(2.0 * sinf(self.angleEye), 2.0 * cosf(self.angleEye), 0.0)
        // 调整观察位置
        self.lookAtPosition = GLKVector3Make(2.0 * sinf(self.angleLook), 2.0 * cosf(self.angleLook), 2.0)
        
        let size             = self.view.bounds.size
        let aspect           = abs(size.width / size.height)
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(85.0), Float(aspect), 0.1, 20.0) // 投影矩阵
        let modelViewMatrix  = GLKMatrix4MakeLookAt(self.eyePosition.x,
                                                    self.eyePosition.y,
                                                    self.eyePosition.z,
                                                    self.lookAtPosition.x,
                                                    self.lookAtPosition.y,
                                                    self.lookAtPosition.z,
                                                    self.upVector.x,
                                                    self.upVector.y,
                                                    self.upVector.z)    // 观察矩阵
        var matrix = SYMatrix(projection: self.metalMatrix(form: projectionMatrix),
                              modelView: self.metalMatrix(form: modelViewMatrix))
        // 创建矩阵数据缓存
        encoder.setVertexBytes(&matrix,
                               length: MemoryLayout<SYMatrix>.size,
                               index: Int(SYVertexInputIndexMatrix.rawValue))
    }

}



extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportSize = vector_uint2(x: UInt32(size.width), y: UInt32(size.height))
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("Create command buffer failure.")
            return
        }
        commandBuffer.label = "SY-command"
        // MTLRenderPassDescriptor 描述一系列 attachments 的值，类似 OpenGL 的 FrameBuffer；同时也用来创建 MTLRenderCommandEncoder
        if let descriptor = view.currentRenderPassDescriptor {
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
                renderEncoder.setRenderPipelineState(self.pipelineState)
                
                // 设置 MVP 矩阵
                self.setupMatrixWith(encoder: renderEncoder)
                
                // 设置顶点缓存
                renderEncoder.setVertexBuffer(self.vertices,
                                              offset: 0,
                                              index: Int(SYVertexInputIndexVertices.rawValue))
                // 设置纹理
                renderEncoder.setFragmentTexture(self.texture,
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
