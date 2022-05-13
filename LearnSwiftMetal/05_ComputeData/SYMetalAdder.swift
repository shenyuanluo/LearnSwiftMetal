//
//  SYMetalAdder.swift
//  05_ComputeData
//
//  Created by ShenYuanLuo on 2022/5/13.
//

import Foundation
import Metal

let kArrayLen: Int = 10000

class SYMetalAdder {
    private var device: MTLDevice                           // 用来渲染的设备（即，GPU）
    private var computePipeline: MTLComputePipelineState!   // 内核计算管线
    private var commandQueue: MTLCommandQueue!              // 命令队列（控制渲染命令按部就班执行）
    
    private var inA: [Float] = Array(repeating: 0, count: kArrayLen)
    private var inB: [Float] = Array(repeating: 0, count: kArrayLen)
    private var result: [Float] = Array(repeating: 0, count: kArrayLen)
    
    private var inABuffer: MTLBuffer?
    private var inBBuffer: MTLBuffer?
    private var resultBuffer: MTLBuffer?
    
    init(_ devi: MTLDevice) {
        self.device = devi
        
        // 从 Bundle 加载所有着色器文件（.metal）
        guard let library = self.device.makeDefaultLibrary() else {
            print("Can not create (.metal) library.")
            return
        }
        // 内核计算函数
        guard let addFunc = library.makeFunction(name: "AddArrays") else {
            print("Can not create kernel compute fun: AddArrays.")
            return
        }
        do {
            // 创建内核计算管线（耗性能，不宜频繁操作）
            self.computePipeline = try self.device.makeComputePipelineState(function: addFunc)
        } catch {
            print("Create compute pipeline failure.")
            return
        }
        // 创建渲染指令队列（保证渲染指令有序地提交到 GPU）
        self.commandQueue = self.device.makeCommandQueue()
    }
    
    // 准备数据
    func prepareData() {
        for i in 0..<kArrayLen {
            inA[i] = Float(i + 1)
            inB[i] = Float(i + 2)
        }
        // 将内容 copy 到一块新的内存区，来创建 buffer
        self.inABuffer = self.device.makeBuffer(bytes: &self.inA,
                                                length: MemoryLayout<Float>.size * kArrayLen,
                                                options: .storageModeShared)    // 使用共享内存(storageModeShared)， CPU 和 GPU都可以访问
        self.inBBuffer = self.device.makeBuffer(bytes: &self.inB,
                                                length: MemoryLayout<Float>.size * kArrayLen,
                                                options: .storageModeShared)
        self.resultBuffer = self.device.makeBuffer(bytes: &self.result,
                                                   length: MemoryLayout<Float>.size * kArrayLen,
                                                   options: .storageModeShared)
    }
    
    // 发送计算命令
    func sendComputeCommand(completion: @escaping(() -> ())) {
        // 创建命令缓存去
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            print("Create command buffer failure.")
            return
        }
        // 创建命令编码器
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Create compute encoder failure.")
            return
        }
        // 设置「计算」管线，以调用 shaders.metal 中的内核计算函数
        computeEncoder.setComputePipelineState(self.computePipeline)
        // 写入数据
        computeEncoder.setBuffer(self.inABuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(self.inBBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(self.resultBuffer, offset: 0, index: 2)
        
        let gridSize = MTLSize(width: 16 < kArrayLen ? 16 : kArrayLen, height: 1, depth: 1)   // 一维数据 height、depth 都是 1
        
        // 决定要创建多少线程以及如何组织这些线程
        var threadGroupSizeWidth = self.computePipeline.maxTotalThreadsPerThreadgroup
        if kArrayLen < threadGroupSizeWidth {
            threadGroupSizeWidth = kArrayLen
        }
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1) // 一维数据 height、depth 都是 1
        
        // 设置计算区域（使用非均匀线程组的网格编码计算命令,该方法能够更有效的利用GPU资源， 但是该方法最低支持到A11处理器(芯片)）
//        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        // 使用均匀线程组边界的网格编码计算命令
        computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)

        // 设置处理完成回调
        commandBuffer.addCompletedHandler { buff in
            print("Compute finish.")
            completion()
            let loop: Int = 10 < kArrayLen ? 10 : kArrayLen
            if let pA = self.inABuffer?.contents(),
               let pB = self.inABuffer?.contents(),
               let pR = self.resultBuffer?.contents() {
                for i in 0..<loop {
                    let a = pA.load(fromByteOffset: MemoryLayout<Float>.size * i, as: Float.self)
                    let b = pB.load(fromByteOffset: MemoryLayout<Float>.size * i, as: Float.self)
                    let r = pR.load(fromByteOffset: MemoryLayout<Float>.size * i, as: Float.self)
                    print("\(a) + \(b) = \(r), result[\(i)] = \(self.result[i])")
                }
            }
        }
        // 结束编码过程以关闭计算传递
        computeEncoder.endEncoding()
        // 交命令缓冲区后，Metal 会异步准备执行的命令，然后调度命令缓冲区在 GPU 上执行。
        // 当 GPU 执行完命令缓冲区中的所有命令后，将命令缓冲区标记为完成。
        commandBuffer.commit()
    }
}
