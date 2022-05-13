//
//  SYShaders.metal
//  05_ComputeData
//
//  Created by ShenYuanLuo on 2022/5/13.
//

#include <metal_stdlib>
using namespace metal;


// 以 kernel 关键字声明一个计算函数（kernel 声明返回值必须是 void）
kernel void
AddArrays(device const float* inA,
          device const float* inB,
          device float* result,
          uint index [[ thread_position_in_grid ]])
{
    result[index] = inA[index] + inB[index];
}

