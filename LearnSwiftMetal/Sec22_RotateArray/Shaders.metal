//
//  Shaders.metal
//  Sec22_RotateArray
//
//  Created by ShenYuanLuo on 2023/4/6.
//

#include <metal_stdlib>
using namespace metal;

/// 旋转数组
kernel void
RotateArray(device const float* inArr,                                  // 原始数组
            device float*       result,                                 // 结果数组
            constant int&       row     [[ buffer(11) ]],               // 数组「行」数
            constant int&       col     [[ buffer(12) ]],               // 数组「列」数
            constant int&       isRight [[ buffer(13) ]],               // 是否向「右」选择（0：左；1：右）
            uint                index   [[ thread_position_in_grid ]]   // 当前计算线程下标（在网格中）
            )
{
    int i = index/col;          // 当前「行」下标
    int j = index - (i * col);  // 当前「列」下标
    if (i < 0 || i >= row || j < 0 || j >= col) // 下标越(网格)界处理
    {
        return;
    }
    int srcIdx = i * col + j;               // 「原始」数下标
    int dstIdx = (col - j - 1) * row + i;   // 「结果」数下标（「左」旋转 90 度）
    if (isRight)
    {
        dstIdx = j * row + (row - i - 1);   // 「右」旋转 90 度下标
    }
    result[dstIdx] = inArr[srcIdx]; // 旋转
}


/// 旋转 YUV-nv12 图像
kernel
void RotateNV12(device const unsigned char* inYUV,                                  // 原始图像
                device unsigned char*       outYUV,                                 // 结果图像
                constant int&               width   [[ buffer(11) ]],               // 图像-宽度（像素）
                constant int&               height  [[ buffer(12) ]],               // 图像-高度（像素）
                constant int&               isRight [[ buffer(13) ]],               // 是否向右旋转（0：向左，1：向右；旋转 90度）
                uint                        index   [[ thread_position_in_grid ]])  // 当前计算线程下标（在网格中）
{
    int row = index / width;        // 当前「行」
    int col = index - row * width;  // 当前「列」
    if (row < 0 || row >= height || col < 0 || col >= width)    // 下标越(网格)界处理
    {
        return;
    }
    int srcYPos     = row * width  + col;                   // 原始「Y」下标
    int dstYPos     = col * height + (height - 1 - row);    // 目的「Y」下标
    outYUV[dstYPos] = inYUV[srcYPos];                       // 旋转「Y」
    
    if ((0 == (row&1))&& (0 == (col&1)))    // YUV-420：4 个 「Y」数据共用一对「UV」数据
    {
        int uvOffset         = width * height;  // 「UV」平面偏移
        int uvHeight         = (height>>1);     // 「UV」平面-高度
        int srcUVRow         = (row>>1);        // 原始「UV」行-下标
        int dstUVCol         = ((uvHeight - 1 - srcUVRow)<<1);         // 目的「UV」列-下标
        int srcUVPos         = uvOffset + srcUVRow * width + col;      // 原始「UV」下标
        int dstUVPos         = uvOffset + col * uvHeight   + dstUVCol; // 目的「UV」下标
        outYUV[dstUVPos]     = inYUV[srcUVPos];                        // 旋转「U」
        outYUV[dstUVPos + 1] = inYUV[srcUVPos + 1];                    // 旋转「V」
    }
}
