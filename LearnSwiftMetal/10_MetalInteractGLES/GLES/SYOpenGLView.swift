//
//  SYOpenGLView.swift
//  10_MetalInteractGLES
//
//  Created by ShenYuanLuo on 2022/5/27.
//

import UIKit
import AVFoundation
import OpenGLES


/// 顶点属性枚举
fileprivate enum VertexAttrib: GLuint {
    /// 顶点位置
    case position = 0
    /// 纹理坐标
    case texCoord = 1
};


/// OpenGL-ES 视图
class SYOpenGLView: UIView {
    private var context: EAGLContext!                   // OpenGL-ES 上下文
    private var program: GLuint = 0                     // 着色器程序对象引用-ID
    private var textureCache: CVOpenGLESTextureCache!   // OpenGL-ES 纹理缓存
    private var inputTexture: CVOpenGLESTexture!        // （Metal）输入纹理
    private var frameBuffer: GLuint = 0                 // 帧缓存
    private var renderBuffer: GLuint = 0                // (颜色)渲染缓存
    private var viewportWidth: GLint = 0                // 视口-宽度
    private var viewportHeight: GLint = 0               // 视口-高度
    
    override class var layerClass: AnyClass {
        return CAEAGLLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentScaleFactor = UIScreen.main.scale
        
        if let eaglLayer = self.layer as? CAEAGLLayer {
            eaglLayer.isOpaque           = true
            eaglLayer.drawableProperties = [
                kEAGLDrawablePropertyRetainedBacking : false,
                kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8]
        }
        self.context = EAGLContext(api: .openGLES2)
        if nil == self.context || false == EAGLContext.setCurrent(self.context) || false == self.loadShaders() {
            print("初始化失败...")
            //            return nil
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.cleanUpTextures()
        if nil != self.textureCache {
            self.textureCache = nil
        }
    }
    
    // MARK: 设置 OpenGL-ES
    func setupGL() {
        if false == EAGLContext.setCurrent(self.context) {  // 设置 OpenGL-ES 上下文失败
            print("Faile to set current content.")
            return
        }
        self.setupBuffes()  // 设置缓存
        if false == self.loadShaders() {
            print("Failed to load shaders.")
            return
        }
        
        // 设置「纹理」uniform 属性值（需先激活，才可以设置）
        glUseProgram(self.program)  // 激活着色器程序
        glUniform1i(glGetUniformLocation(self.program, "texture"), 0) // 设置「纹理」uniform 属性值
        
        // 创建 CVOpenGLESTextureCache（用于 CVPixelBuffer 转 GLES 纹理）
        if nil == self.textureCache {
            let ret = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                   nil,
                                                   self.context,
                                                   nil,
                                                   &self.textureCache)
            if noErr != ret {
                print("Error at CVOpenGLES texture cache create: \(ret)")
                return
            }
        }
    }
    
    // MARK: 显示像素纹理数据
    func display(_ pixelBuffer: CVPixelBuffer?) {
        if let pixelBuffer = pixelBuffer {
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            let frameWidth  = CVPixelBufferGetWidth(pixelBuffer)
            let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
            if nil == self.textureCache {
                print("OpenGL-ES texture cache is nil.")
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
                return
            }
            // 设置为当前上下文
            if EAGLContext.current() != self.context {
                EAGLContext.setCurrent(self.context)    // 这个一定要设置
            }
            self.cleanUpTextures()
            
            // 先激活对应的纹理单元
            glActiveTexture(GLenum(GL_TEXTURE0))
            // 从 pixelBuffer 创建纹理
            let ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                   self.textureCache,
                                                                   pixelBuffer,
                                                                   nil,
                                                                   GLenum(GL_TEXTURE_2D),
                                                                   GLint(GL_RGBA),
                                                                   GLsizei(frameWidth),
                                                                   GLsizei(frameHeight),
                                                                   GLenum(GL_RGBA),
                                                                   GLenum(GL_UNSIGNED_BYTE),
                                                                   0,
                                                                   &self.inputTexture)
            if kCVReturnSuccess != ret {
                print("Error at CVOpenGLES texture cache create texture from inmage: \(ret)")
            }
            // 绑定纹理
            glBindTexture(CVOpenGLESTextureGetTarget(self.inputTexture), CVOpenGLESTextureGetName(self.inputTexture))
            // 设置纹理过滤模式
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)    // 缩小过滤模式
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)    // 放大过滤模式
            // 设置纹理环绕模式
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))    // S 轴环绕
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))    // T 轴环绕
            
            // 绑定帧缓存
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.frameBuffer)
            
            // 设置视口大小
            glViewport(0, 0, self.viewportWidth, self.viewportHeight)
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        glClearColor(0.0, 0.5, 0.1, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        // 使用(指定)着色器程序
        glUseProgram(self.program)
        
        // 视口「宽-高」比率
        let ratio = CGSize(width: CGFloat(self.viewportWidth),
                           height: CGFloat(self.viewportHeight))
        // 纹理采样矩形位置（根据视口大小比例）
        let vertexSamplingRect = AVMakeRect(aspectRatio: ratio,
                                            insideRect: self.layer.bounds)
        
        
        // Compute normalized quad coordinates to draw the frame into.
        var normalizedSamplingSize = CGSize(width: 0.0, height: 0.0)
        let cropScaleAmount = CGSize(width: vertexSamplingRect.size.width / self.layer.bounds.size.width,
                                     height: vertexSamplingRect.size.height / self.layer.bounds.size.height)
        
        // 归一化（标准化设备坐标）采样纹理坐标
        if (cropScaleAmount.width > cropScaleAmount.height) {
            normalizedSamplingSize.width  = 1.0
            normalizedSamplingSize.height = cropScaleAmount.height / cropScaleAmount.width
        } else {
            normalizedSamplingSize.height = 1.0
            normalizedSamplingSize.width  = cropScaleAmount.width / cropScaleAmount.height
        }
        
        // 顶点位置数据（左下角：(-1, -1)；右上角：(1, 1)）
        let quadVertexData: [GLfloat] = [
            
            -1 * GLfloat(normalizedSamplingSize.width), -1 * GLfloat(normalizedSamplingSize.height),    // 左下
                 GLfloat(normalizedSamplingSize.width), -1 * GLfloat(normalizedSamplingSize.height),    // 右下
            -1 * GLfloat(normalizedSamplingSize.width),      GLfloat(normalizedSamplingSize.height),    // 左下
                 GLfloat(normalizedSamplingSize.width),      GLfloat(normalizedSamplingSize.height),    // 右上
        ]
        // 纹理坐标数据（左上角：(0, 0)；右下角：(1, 1)）
        let quadTextureData: [GLfloat] =  [
            0, 1,   // 左下
            1, 1,   // 右下
            0, 0,   // 左上
            1, 0    // 右上
        ]
        // 设置顶点「顶点-位置」属性（告诉 OpenGL 如何解释使用顶点位置数据）
        glVertexAttribPointer(VertexAttrib.position.rawValue,
                              2,
                              GLenum(GL_FLOAT),
                              GLboolean(GL_FALSE),
                              0,
                              quadVertexData)
        // 启用顶点「顶点-位置」属性
        glEnableVertexAttribArray(VertexAttrib.position.rawValue)
        // 设置顶点「纹理-坐标」属性（告诉 OpenGL 如何解释使用纹理坐标数据）
        glVertexAttribPointer(VertexAttrib.texCoord.rawValue,
                              2,
                              GLenum(GL_FLOAT),
                              GLboolean(GL_FALSE),
                              0,
                              quadTextureData)
        // 启用顶点「纹理-坐标」属性
        glEnableVertexAttribArray(VertexAttrib.texCoord.rawValue)
        
        // 开始绘制
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
        
        // 绑定帧缓存·渲染缓存对象附近
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), self.renderBuffer)
        
        if EAGLContext.current() == self.context {
            // 显示帧缓存
            self.context.presentRenderbuffer(Int(GL_RENDERBUFFER))
        }
    }
    
    // MARK: 设置缓存
    private func setupBuffes() {
        // 禁用深度测试
        glDisable(GLenum(GL_DEPTH_TEST))
        // 启用顶点属性
        glEnableVertexAttribArray(VertexAttrib.position.rawValue)
        // 设置颜色属性（告诉 OpenGL 如何解释使用顶点数据）
        glVertexAttribPointer(VertexAttrib.position.rawValue,
                              2,
                              GLenum(GL_FLOAT),
                              GLboolean(GL_FALSE),
                              GLsizei(2 * MemoryLayout<GLfloat>.size),
                              self.buffer(offset: 0))
        // 启用纹理属性
        glEnableVertexAttribArray(VertexAttrib.texCoord.rawValue)
        // 设置纹理属性（告诉 OpenGL 如何解释使用纹理数据）
        glVertexAttribPointer(VertexAttrib.texCoord.rawValue,
                              2,
                              GLenum(GL_FLOAT),
                              GLboolean(GL_FALSE),
                              2 * Int32(MemoryLayout<GLfloat>.size),
                              self.buffer(offset: 1))
        // 创建帧缓存
        glGenFramebuffers(1, &self.frameBuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.frameBuffer)   // 绑定帧缓存
        // 创建渲染缓存
        glGenRenderbuffers(1, &self.renderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), self.renderBuffer) // 绑定渲染缓存
        //  创建渲染缓冲对象
        self.context.renderbufferStorage(Int(GL_RENDERBUFFER), from: self.layer as? EAGLDrawable)
        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_WIDTH), &self.viewportWidth)
        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_HEIGHT), &self.viewportHeight)
        // 将渲染缓冲附件添加到帧缓冲上
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), self.renderBuffer)
        // 检查创建的帧缓冲是否完整
        if (glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) != GL_FRAMEBUFFER_COMPLETE) {
            print("Failed to make complete framebuffer object \(glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)))")
        }
    }
    
    // MARK: 清空纹理
    private func cleanUpTextures() {
        if nil != self.inputTexture {
            self.inputTexture = nil
        }
        // 刷新纹理缓存
        CVOpenGLESTextureCacheFlush(self.textureCache, 0)
    }
    
    // MARK: 加载着色器
    private func loadShaders() -> Bool {
        var vertShader: GLuint = 0  // 顶点着色器引用-ID
        var fragShader: GLuint = 0  // 片段着色器引用-ID
        guard let vertShaderURL = Bundle.main.url(forResource: "VertexShader", withExtension: "vsh"),
              let fragShaderURL = Bundle.main.url(forResource: "FragmentShader", withExtension: "fsh") else {
            print("Failed find shaders file url.")
            return false
        }
        self.program = glCreateProgram()
        // 编译「顶点」着色器
        var ret = self.compile(shader: &vertShader, type: GLenum(GL_VERTEX_SHADER), url: vertShaderURL)
        if false == ret {
            print("Failed to compile vertex shader.")
            return false
        }
        // 编译「片段」着色器
        ret = self.compile(shader: &fragShader, type: GLenum(GL_FRAGMENT_SHADER), url: fragShaderURL)
        if false == ret {
            print("Failed to compile fragment shader.")
            return false
        }
        // 添加着色器
        glAttachShader(self.program, vertShader)    // 添加「顶点」着色器
        glAttachShader(self.program, fragShader)    // 添加「片段」着色器
        // 绑定顶点属性位置
        glBindAttribLocation(self.program, VertexAttrib.position.rawValue, "position")
        glBindAttribLocation(self.program, VertexAttrib.texCoord.rawValue, "texCoord")
        // 链接着色器程序
        ret = self.link(program: self.program)
        if false == ret {   // 链接着色器程序失败
            print("Failed to ink program: \(self.program)")
            if 0 < vertShader {
                glDeleteShader(vertShader)
            }
            if 0 < fragShader {
                glDeleteShader(fragShader)
            }
            if 0 < self.program {
                glDeleteProgram(self.program)
                self.program = 0
            }
            return false
        }
        // 链接着色器程序成功后，可以释放着色器
        if 0 < vertShader { // 释放「顶点」着色器
            glDetachShader(self.program, vertShader)
            glDeleteShader(vertShader)
        }
        if 0 < fragShader { // 释放「片段」着色器
            glDetachShader(self.program, fragShader)
            glDeleteShader(fragShader)
        }
        return true
    }
    
    // MARK: 编译着色器源码
    private func compile(shader: UnsafeMutablePointer<GLuint>, type: GLenum, url: URL) -> Bool {
        do {
            let sourceString  = try String(contentsOf: url, encoding: .utf8)    // 读取源码
            var sourceCString = (sourceString as NSString).utf8String
            shader.pointee    = glCreateShader(type)    // 创建着色器
            glShaderSource(shader.pointee, 1, &sourceCString, nil)  // 执行创建着色器 GLSL 的源码
            glCompileShader(shader.pointee) // 编译 GLSL 源码
#if DEBUG
            var logLength: GLint = 0
            glGetShaderiv(shader.pointee, GLenum(GL_INFO_LOG_LENGTH), &logLength)   // 获取编译 log 信息长度
            if 0 < logLength {
                let log = UnsafeMutableRawPointer.allocate(byteCount: Int(logLength), alignment: 8)
                glGetShaderInfoLog(shader.pointee, logLength, &logLength, log)  // 获取编译 log 信息
                print("Shader compile log: \(log)")
                free(log)
            }
#endif
            var success: GLint = 0
            glGetShaderiv(shader.pointee, GLenum(GL_COMPILE_STATUS), &success)  // 检查编译 GLSL 是否出错
            if 0 == success {
                glDeleteShader(shader.pointee)
                return false
            }
        } catch let error as NSError {
            print("Failed to load shader: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    // MARK: 链接着色器程序
    private func link(program: GLuint) -> Bool {
        glLinkProgram(program)  // 链接着色器程序
#if DEBUG
        var logLength: GLint = 0
        glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength) // 获取着色器程序 log 信息长度
        if 0 < logLength {
            let log = UnsafeMutableRawPointer.allocate(byteCount: Int(logLength), alignment: 8)
            glGetProgramInfoLog(program, logLength, &logLength, log)    // 获取着色器程序 log 信息
            print("Shader compile log: \(log)")
            free(log)
        }
#endif
        var status: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)    // 检查着色器程序「链接」是否出错
        if 0 == status {
            return false
        }
        return true
    }
    
    // MARK: 获取缓存指定偏移指针
    fileprivate func buffer(offset: Int) -> UnsafeRawPointer? {
        return UnsafeRawPointer(bitPattern: offset)
    }
}

