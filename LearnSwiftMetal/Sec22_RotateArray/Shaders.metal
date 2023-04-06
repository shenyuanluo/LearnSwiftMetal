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
            device float* result,
            constant int &row [[ buffer(11) ]],
            constant int &col [[ buffer(12) ]],
            constant int &isLeft [[ buffer(13) ]],
            uint index [[ thread_position_in_grid ]])
{
    for (int i = 0; i < row; i++)   // 遍历所有「行」
    {
        for (int j = 0; j < col; j++)   // 遍历所有「列」
        {
            int oriIdx = i * col + j;               // 「原始」数组下标
            int retIdx = (col - j - 1) * row + i;   // 「结果」数组下标（「左」旋转 90 度）
            if (!isLeft)    // 「右」旋转 90 度
            {
                retIdx = j * row + (row - i - 1);
            }
            result[retIdx] = inArr[oriIdx];
        }
    }
}
