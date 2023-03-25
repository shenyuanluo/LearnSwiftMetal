//
//  ViewController.swift
//  03_RenderCamera
//
//  Created by ShenYuanLuo on 2022/5/12.
//

import UIKit
import MetalKit
import AVFoundation
import MetalPerformanceShaders  // Metal 的一个集成库，有一些滤镜处理的 Metal 实现
    
class ViewController: UIViewController {
    private var mtkView: MTKView!                       // 用于处理 Metal 绘制并显示
    private var device: MTLDevice!                      // 用来渲染的设备（即，GPU）
    private var commandQueue: MTLCommandQueue!          // 命令队列（控制渲染命令按部就班执行）
    private var texture: MTLTexture!                    // 纹理对象
    
    private var textureCache: CVMetalTextureCache!      // Core Video 的 Metal 纹理缓存
    private var captureSession: AVCaptureSession!       // 相机会话
    private var captureInput: AVCaptureDeviceInput!     // 相机输入
    private var captureOutput: AVCaptureVideoDataOutput!// 视频输出
    private let processQueue = DispatchQueue(label: "com.sy.processQueue")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupMetal()
        
        self.setupCaptureSession()
    }
    
    // MARK: 设置 Metal
    private func setupMetal() {
        self.mtkView        = MTKView(frame: self.view.bounds)
        self.mtkView.device = MTLCreateSystemDefaultDevice()
        if nil == self.mtkView.device { // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        self.mtkView.delegate        = self
        self.mtkView.framebufferOnly = false    // 设置 MTKView 的 drawable 纹理可读写（默认只读）
        self.device                  = self.mtkView.device
        self.view.insertSubview(self.mtkView, at: 0)
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()

        // 创建纹理缓存区
        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.textureCache)
    }
    
    // MARK: 设置视频录制
    private func setupCaptureSession() {
        self.captureSession               = AVCaptureSession()
        self.captureSession.sessionPreset = .hd1920x1080
        var inputCamera: AVCaptureDevice!
        let devSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
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
        self.captureOutput.alwaysDiscardsLateVideoFrames = false    // 设置视频帧延迟到底时是否丢弃数据（NO，有更多时间处理，但会增加内存）
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
        DispatchQueue.global().async {
            self.captureSession.startRunning()  // 启动相机
            
        }
    }
}


extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        if nil != self.texture {
            // 创建指令缓冲
            guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                print("Create command buffer failure.")
                return
            }
            // 把 MKTView 作为目标纹理
            let drawingTexture = view.currentDrawable?.texture
            // 高斯模糊过滤器（sigma 值越高图像越模糊）
            let filter = MPSImageGaussianBlur(device: self.device, sigma: 3)
            // 高斯模糊处理
            filter.encode(commandBuffer: commandBuffer,
                          sourceTexture: self.texture,
                          destinationTexture: drawingTexture!)

            commandBuffer.present(view.currentDrawable!)    // 显示
            commandBuffer.commit()  // 提交
        }
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
            self.texture = CVMetalTextureGetTexture(tmpTexture!)
        }
        
        CVPixelBufferUnlockBaseAddress(pixelbuffer, .readOnly)
    }
}

