//
//  ViewController.swift
//  02_Transformation
//
//  Created by ShenYuanLuo on 2022/5/10.
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
    
    private var rotateX: Float = 0.0  // 绕 X 轴旋转角度
    private var rotateY: Float = 0.0  // 绕 Y 轴旋转角度
    private var rotateZ: Float = .pi  // 绕 Z 轴旋转角度
    
    private lazy var xLabel: UILabel = {
        let label       = UILabel(frame: CGRect(x: 20, y: 20, width: 40, height: 20))
        label.text      = "X轴"
        label.textColor = .black
        return label
    }()
    private lazy var xSwitch: UISwitch = {
        let uiSwitch  = UISwitch(frame: CGRect(x: 80, y: 20, width: 40, height: 20))
        uiSwitch.isOn = false
        return uiSwitch
    }()
    private lazy var yLabel: UILabel = {
        let label       = UILabel(frame: CGRect(x: 20, y: 60, width: 40, height: 20))
        label.text      = "Y轴"
        label.textColor = .black
        return label
    }()
    private lazy var ySwitch: UISwitch = {
        let uiSwitch  = UISwitch(frame: CGRect(x: 80, y: 60, width: 40, height: 20))
        uiSwitch.isOn = false
        return uiSwitch
    }()
    private lazy var zLabel: UILabel = {
        let label       = UILabel(frame: CGRect(x: 20, y: 100, width: 40, height: 20))
        label.text      = "Z轴"
        label.textColor = .black
        return label
    }()
    private lazy var zSwitch: UISwitch = {
        let uiSwitch  = UISwitch(frame: CGRect(x: 80, y: 100, width: 40, height: 20))
        uiSwitch.isOn = true
        return uiSwitch
    }()
    private lazy var rotateLabel: UILabel = {
        let label           = UILabel(frame: CGRect(x: 180, y: 60, width: 150, height: 20))
        label.text          = "旋转速率"
        label.textColor     = .black
        label.textAlignment = .center
        return label
    }()
    private lazy var slider: UISlider = {
        let slider          = UISlider(frame: CGRect(x: 180, y: 100, width: 150, height: 2))
        slider.minimumTrackTintColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0)
        slider.maximumTrackTintColor = UIColor(red: 0.6, green: 0.6, blue: 0.8, alpha: 1.0)
        slider.value        = 0.02
        slider.minimumValue = 0.01
        slider.maximumValue = 0.05
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
    
    // MARK: UI 设置
    private func configUI() {
        self.view.addSubview(self.xLabel)
        self.view.addSubview(self.yLabel)
        self.view.addSubview(self.zLabel)
        
        self.view.addSubview(self.xSwitch)
        self.view.addSubview(self.ySwitch)
        self.view.addSubview(self.zSwitch)
        
        self.view.addSubview(self.rotateLabel)
        self.view.addSubview(self.slider)
    }

    // MARK: 初始化
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
        descriptor.label                           = "SY-Pipeline"
        descriptor.vertexFunction                  = vertexFun
        descriptor.fragmentFunction                = fragmentFun
        descriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat
        // 创建图形渲染管线（耗性能，不宜频繁操作）
        self.pipelineState = try! self.device.makeRenderPipelineState(descriptor: descriptor)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()
    }
    
    // MARK: 设置顶点数据缓存
    private func setupVertex() {
        // 椎体顶点数据
        let quadVertices = [ // 顶点坐标                        顶点颜色                             纹理坐标
            SYVertex(position: [-0.5,  0.5, 0.0, 1.0], color: [0.0, 0.0, 0.5], textureCoordinate: [0.0, 1.0]),  // 左上
            SYVertex(position: [ 0.5,  0.5, 0.0, 1.0], color: [0.0, 0.5, 0.0], textureCoordinate: [1.0, 1.0]),  // 右上
            SYVertex(position: [-0.5, -0.5, 0.0, 1.0], color: [0.5, 0.0, 1.0], textureCoordinate: [0.0, 0.0]),  // 左下
            SYVertex(position: [ 0.5, -0.5, 0.0, 1.0], color: [0.0, 0.0, 0.5], textureCoordinate: [1.0, 0.0]),  // 右下
            SYVertex(position: [ 0.0,  0.0, 1.0, 1.0], color: [1.0, 1.0, 1.0], textureCoordinate: [0.5, 0.5]),  // 顶点
        ]
        // 创建顶点数据缓存
        self.vertices = self.device.makeBuffer(bytes: quadVertices,
                                               length: MemoryLayout<SYVertex>.size * quadVertices.count,
                                               options: .storageModeShared)
        self.numVertices = quadVertices.count
        /* 索引数据
         注意：这里一定要指定数据类型为 UInt32/UInt16，不能使用默认的 Int，
              且必须与 drawIndexedPrimitives 的 indexType 类型一致，
              否则会出现解析索引数据异常问题
         */
        let indices: [UInt16] = [
            0, 3, 2,
            0, 1, 3,
            0, 2, 4,
            0, 4, 1,
            2, 3, 4,
            1, 4, 3
        ]
        // 创建索引数据缓存
        self.indices = self.device.makeBuffer(bytes: indices,
                                              length: MemoryLayout<Int>.size * indices.count,
                                              options: .storageModeShared)
        self.numIndices = indices.count
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
        self.texture           = self.device.makeTexture(descriptor: descriptor)    // 创建纹理
        // 纹理上传范围
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(img.size.width), height: Int(img.size.height), depth: 1))
        // UIImage 的数据需要转成二进制才能上传，且不用 jpg、png 的 NSData
        guard let data = UIImage.loadImage(img) else {
            print("Load image data failure.")
            return
        }
        // 拷贝图像数据到纹理
        self.texture.replace(region: region,
                             mipmapLevel: 0,
                             withBytes: data,
                             bytesPerRow: Int(img.size.width) * 4)
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
    private func setupMatrix(with renderEncoder: MTLRenderCommandEncoder) {
        let size             = self.view.bounds.size
        let aspect           = abs(Float(size.width) / Float(size.height))
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90.0), aspect, 0.1, 10.0)
        var modelViewMatrix  = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, -2.0)
        
        if self.xSwitch.isOn {
            rotateX += self.slider.value
        }
        if self.ySwitch.isOn {
            rotateY += self.slider.value
        }
        if self.zSwitch.isOn {
            rotateZ += self.slider.value
        }
        
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotateX, 1, 0, 0)   // 绕 X 轴旋转
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotateY, 0, 1, 0)   // 绕 Y 轴旋转
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotateZ, 0, 0, 1)   // 绕 Z 轴旋转
        
        var matrix = SYMatrix(projectionMatrix: self.metalMatrix(form: projectionMatrix),
                              modelViewMatrix: self.metalMatrix(form: modelViewMatrix))
        // 创建矩阵数据缓存
        renderEncoder.setVertexBytes(&matrix,
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
                self.setupMatrix(with: renderEncoder)
                
                // 设置顶点缓存
                renderEncoder.setVertexBuffer(self.vertices,
                                              offset: 0,
                                              index: Int(SYVertexInputIndexVertices.rawValue))
                // 设置正面向顶点环绕顺序（顺时针）
                renderEncoder.setFrontFacing(MTLWinding.clockwise)
                // 设置面剔除方式（背面剔除）
                renderEncoder.setCullMode(MTLCullMode.back)
                
                // 设置纹理
                renderEncoder.setFragmentTexture(self.texture,
                                                 index: Int(SYFragmentInputIndexTexture.rawValue))
                // 开始绘制
                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: self.numIndices,
                                                    indexType: .uint16,
                                                    indexBuffer: self.indices,
                                                    indexBufferOffset: 0)
                renderEncoder.endEncoding() // 结束
            }
            commandBuffer.present(view.currentDrawable!)    // 显示
        }
        commandBuffer.commit()  // 提交
    }
}

