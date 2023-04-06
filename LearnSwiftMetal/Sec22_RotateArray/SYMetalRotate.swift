//
//  SYMetalRotate.swift
//  Sec22_RotateArray
//
//  Created by ShenYuanLuo on 2023/4/6.
//

import Foundation
import Metal

let kArrayRow: Int = 1920
let kArrayCol: Int = 1440
let kArrayLen: Int = kArrayRow * kArrayCol // 1_000_000
let kIsRotateLeft: Int = 0

class SYMetalAdder {
    private var device: MTLDevice                           // 用来渲染的设备（即，GPU）
    private var computePipeline: MTLComputePipelineState!   // 内核计算管线
    private var commandQueue: MTLCommandQueue!              // 命令队列（控制渲染命令按部就班执行）
    
    private var inArray: [Float] = Array(repeating: 0, count: kArrayLen)
    private var result: [Float] = Array(repeating: 0, count: kArrayLen)
    
    private var inBuffer: MTLBuffer?
    private var outBuffer: MTLBuffer?
    
    init(_ devi: MTLDevice) {
        self.device = devi
        
        // 从 Bundle 加载所有着色器文件（.metal）
        guard let library = self.device.makeDefaultLibrary() else {
            print("Can not create (.metal) library.")
            return
        }
        // 内核计算函数
        guard let addFunc = library.makeFunction(name: "RotateArray") else {
            print("Can not create kernel compute fun: RotateArray.")
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
            inArray[i] = Float.random(in: 0...1)
        }
        // 将内容 copy 到一块新的内存区，来创建 buffer
        self.inBuffer = self.device.makeBuffer(bytes: inArray,
                                                length: MemoryLayout<Float>.size * kArrayLen,
                                                options: .storageModeShared)    // 使用共享内存(storageModeShared)， CPU 和 GPU都可以访问
        self.outBuffer = self.device.makeBuffer(bytes: result,
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
        var row = kArrayRow
        var col = kArrayCol
        var isLeft = kIsRotateLeft
        computeEncoder.setBytes(&row, length: MemoryLayout<Int>.stride, index: 11)
        computeEncoder.setBytes(&col, length: MemoryLayout<Int>.stride, index: 12)
        computeEncoder.setBytes(&isLeft, length: MemoryLayout<Int>.stride, index: 13)
        computeEncoder.setBuffer(self.inBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(self.outBuffer, offset: 0, index: 1)
        
        let executeWidth = self.computePipeline.threadExecutionWidth
        let groupSize    = MTLSize(width: executeWidth, height: 1, depth: 1)   // 一维数据 height、depth 都是 1
        let groupCount   = MTLSize(width: (kArrayLen + groupSize.width - 1) / groupSize.width,
                                   height: 1, depth: 1)   // 一维数据 height、depth 都是 1
        
        // 设置计算区域（使用非均匀线程组的网格编码计算命令,该方法能够更有效的利用GPU资源， 但是该方法最低支持到A11处理器(芯片)）
//        computeEncoder.dispatchThreads(groupCount, threadsPerThreadgroup: groupSize)
        // 使用均匀线程组边界的网格编码计算命令
        computeEncoder.dispatchThreadgroups(groupCount, threadsPerThreadgroup: groupSize)

        // 设置处理完成回调
        commandBuffer.addCompletedHandler { buff in
            completion()
            
            // 拷贝数据到结果数组 result
            if let rawPointer = self.outBuffer?.contents() {
                memcpy(&self.result, rawPointer, MemoryLayout<Float>.size * kArrayLen)
            }
            
            // 打印结果
//            print("原始数组: ")
//            for i in 0..<kArrayRow {
//                for j in 0..<kArrayCol {
//                    let idx = i * kArrayCol + j
//                    print(self.inArray[idx], separator: "", terminator: ", ")
//                }
//                print("")
//            }
//            print("")
//
//            print("结果数组: ")
//            for i in 0..<kArrayCol {
//                for j in 0..<kArrayRow {
//                    let idx = i * kArrayRow + j
//                    print(self.result[idx], separator: "", terminator: ", ")
//                }
//                print("")
//            }
//            print("")
        }
        // 结束编码过程以关闭计算传递
        computeEncoder.endEncoding()
        // 交命令缓冲区后，Metal 会异步准备执行的命令，然后调度命令缓冲区在 GPU 上执行。
        // 当 GPU 执行完命令缓冲区中的所有命令后，将命令缓冲区标记为完成。
        commandBuffer.commit()
    }
}

