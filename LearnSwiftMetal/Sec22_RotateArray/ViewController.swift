//
//  ViewController.swift
//  Sec22_RotateArray
//
//  Created by ShenYuanLuo on 2023/4/6.
//

import UIKit

let kArrayRow: Int = 1920
let kArrayCol: Int = 1440
let kArrayLen: Int = kArrayRow * kArrayCol
let kIsRotateRight: Int = 0
let kIsPrintResult: Int = 0

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.computeDataOnCpu()
        
        self.computeDataOnGpu()
    }
    
    private func computeDataOnCpu(_ loop: Int = 0) {
        print("Rotate array on CPU...(\(loop))")
        var inArray: [Float]  = Array(repeating: 0, count: kArrayLen)
        var result: [Float] = Array(repeating: 0, count: kArrayLen)
        for i in 0..<kArrayLen {
            inArray[i] = Float(i + 1)
        }
        let start = Date()
        // 开始旋转
        for i in 0..<kArrayRow {
            for j in 0..<kArrayCol {
                let oriIdx = i * kArrayCol + j
                var tarIdx = (kArrayCol - j - 1) * kArrayRow + i
                if 1 == kIsRotateRight {
                    tarIdx = j * kArrayRow + (kArrayRow - i - 1)
                }
                result[tarIdx] = inArray[oriIdx]
            }
        }
        let end = Date()
        print("CPU-耗时: \(end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate)")
        // 打印结果
        if 1 == kIsPrintResult {
            print("原始数组: ")
            for i in 0..<kArrayRow {
                for j in 0..<kArrayCol {
                    let idx = i * kArrayCol + j
                    print(inArray[idx], separator: "", terminator: ", ")
                }
                print("")
            }
            print("")
            
            print("结果数组: ")
            for i in 0..<kArrayCol {
                for j in 0..<kArrayRow {
                    let idx = i * kArrayRow + j
                    print(result[idx], separator: "", terminator: ", ")
                }
                print("")
            }
        }
        print("")
    }

    private func computeDataOnGpu(_ loop: Int = 0) {
        guard let device = MTLCreateSystemDefaultDevice() else {    // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        print("Rotate array on GPU...(\(loop))")
        let adder = SYMetalAdder(device)
        adder.prepareData()
        let start = Date()
        adder.sendComputeCommand {
            let end = Date()
            print("GPU-耗时: \(end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate)")
        }
    }
    
    
}

