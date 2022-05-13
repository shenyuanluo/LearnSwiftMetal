//
//  ViewController.swift
//  05_ComputeData
//
//  Created by ShenYuanLuo on 2022/5/13.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        self.computeDataOnCpu()
        
        self.computeDataOnGpu()
    }
    
    private func computeDataOnCpu() {
        print("Compute data on cpu...")
        var inA: [Float] = Array(repeating: 0, count: kArrayLen)
        var inB: [Float] = Array(repeating: 0, count: kArrayLen)
        var result: [Float] = Array(repeating: 0, count: kArrayLen)
        for i in 0..<kArrayLen {
            inA[i] = Float(i)
            inB[i] = Float(i)
        }
        let start = Date()
        // 开始计算
        for i in 0..<kArrayLen {
            result[i] = inA[i] + inB[i];
        }
        let end = Date()
        print("CPU-耗时: \(end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate)")
    }

    private func computeDataOnGpu() {
        guard let device = MTLCreateSystemDefaultDevice() else {    // 设备不支持 Metal
            print("Metal is not support on this device.")
            return
        }
        print("Compute data on gpu...")
        let adder = SYMetalAdder(device)
        adder.prepareData()
        let start = Date()
        adder.sendComputeCommand {
            let end = Date()
            print("GPU-耗时: \(end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate)")
        }
    }
    
    
}

