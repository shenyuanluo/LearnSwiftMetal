//
//  ViewController.swift
//  Sec22_RotateArray
//
//  Created by ShenYuanLuo on 2023/4/6.
//

import UIKit

class ViewController: UIViewController {
    private lazy var rotater: SYMetalRotater = {
        return SYMetalRotater()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.testRotateArray()
        self.testRotateNV12()
    }
    
    /// 测试旋转数组数据
    private func testRotateArray() {
        let row      = 10
        let col      = 50
        let arrayLen = row * col
        let isRight  = 0
        var data     = Array<Float>(repeating: 0, count: arrayLen)
        for i in 0..<arrayLen {
            data[i] = Float(i + 1)
        }
        self.rotater.rotateArray(data: data, row: row, col: col, isRight: isRight) { buff in
            // 拷贝数据到结果数组 result
            if let buff = buff {
                print("原始数组: ")
                for i in 0..<row {
                    for j in 0..<col {
                        let idx = i * col + j
                        print(data[idx], separator: "", terminator: ", ")
                    }
                    print("")
                }
                print("")
                
                print("结果数组: ")
                for i in 0..<col {
                    for j in 0..<row {
                        let idx = i * row + j
                        let val = buff.load(fromByteOffset: idx * MemoryLayout<Float>.size, as: Float.self)
                        print(val, separator: "", terminator: ", ")
                    }
                    print("")
                }
                print("")
            }
        }
    }
    
    /// 测试旋转 NV12 图像
    private func testRotateNV12() {
        let fn  = "1920_1440_nv12"
        let ofp = SYSandboxTools.documentPath() + "/" + fn + "rotate_right.yuv"
        if SYSandboxTools.isExistFile(at: ofp) {
            SYSandboxTools.deleteFile(at: ofp)
        }
        guard let ifp = Bundle.main.path(forResource: fn, ofType: "yuv"),
              let ips = InputStream(fileAtPath: ifp),
              let ops = OutputStream(toFileAtPath: ofp, append: false)else {
            fatalError("Can not find NV12 file path")
        }
        var srcCnt  = 0
        var dstCnt  = 0
        let isRight = 1
        let width   = 1920
        let height  = 1440
        let buffLen = Int(Float(width * height) * 1.5)
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: buffLen, alignment: 1)
        pointer.initializeMemory(as: UInt8.self, repeating: 0, count: buffLen)
        ips.open()
        ops.open()
        while ips.streamStatus != .atEnd {
            let rSize = ips.read(pointer, maxLength: buffLen)
            if rSize != buffLen {
                continue
            }
            srcCnt += 1
            let start  = Date()
            self.rotater.rotateNV12(data: pointer,
                                    width: width,
                                    height: height,
                                    isRight: isRight) { buff in
                if let buff = buff {
                    let wSize = ops.write(buff, maxLength: buffLen)
                    dstCnt   += 1
                    let duration = Date().timeIntervalSince1970 - start.timeIntervalSince1970
                    print("旋转并写入: \(wSize)，耗时: \(duration)s")
                    if dstCnt == srcCnt {
                        pointer.deallocate()
                        ops.close()
                        print("旋转 NV12 完成")
                    }
                }
            }
        }
        ips.close()
    }
    
    
}

