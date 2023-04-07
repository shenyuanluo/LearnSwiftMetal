//
//  Shaders.metal
//  Sec22_RotateArray
//
//  Created by ShenYuanLuo on 2023/4/6.
//

#include <metal_stdlib>
using namespace metal;


// 以 kernel 关键字声明一个计算函数（kernel 声明返回值必须是 void）
kernel void
RotateArray(device const float* inArr,
            device float*       result,
            constant int&       row     [[ buffer(11) ]],               // 二维数组「行」数
            constant int&       col     [[ buffer(12) ]],               // 二维数组「列」数
            constant int&       isRight [[ buffer(13) ]],               // 是否向「右」选择（0：左；1：右）
            uint index                  [[ thread_position_in_grid ]]
            )
{
    int i = index/col;
    int j = index - (i * col);
    int srcIdx = i * col + j;               // 「原始」数组下标
    int dstIdx = (col - j - 1) * row + i;   // 「结果」数组下标（「左」旋转 90 度）
    if (isRight)    // 「右」旋转 90 度
    {
        dstIdx = j * row + (row - i - 1);
    }
    result[dstIdx] = inArr[srcIdx];
}
