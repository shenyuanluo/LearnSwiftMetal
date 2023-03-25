//
//  SYShaders.metal
//  Sec14_HexagonMosaic
//
//  Created by ShenYuanLuo on 2022/6/9.
//

#include <metal_stdlib>
#include "SYShaderTypes.h"

using namespace metal;


/// 光栅化结果数据结构体
typedef struct {
    /// 裁剪空间位置
    float4 clipSpacePosition [[ position ]];    // position 修饰表示这个是顶点
    /// 纹理-坐标（会做插值处理）
    float2 textureCoordinate;
}RasterizerData;

constant float mosaicSize = 0.01;   // 马赛克大小


/// 顶点着色器
vertex RasterizerData
VertexShader(uint vertexID [[ vertex_id ]], // vertex_id 修饰表示这个是着色器每次处理的顶点下标（用于定位当前顶点）
             constant SYVertex* vertexArray [[ buffer(SYVertexInputIndexVertices) ]])   // buffer 表明是缓冲数据（SYVertexBufferIndexVertices 是索引）
{
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;    // 纹理坐标（会进行插值处理）
    return out;
}



/// 片段着色器
fragment float4
FragmentShader(RasterizerData input [[ stage_in ]], // stage_in 表示这个数据来自光栅化（光栅化是顶点处理后的步骤，业务层无法修改）
               texture2d<float> colorTexure [[ texture(SYFragmentInputIndexTexture) ]]) // texture 表示是纹理数据（SYFragmentInputIndexTexture 是索引）
{
    // 纹理采样器
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float lenght = mosaicSize;
    // (width, height), 宽为3，高为根号3的矩形
    float width  = 3;
    float height = 1.732050;
    int xIndex   = input.textureCoordinate.x / (width * lenght);
    int yIndex   = input.textureCoordinate.y / (height * lenght); // 第(x,y)个标志
    float2 pos1;
    float2 pos2;
    // 奇偶判断，横坐标和纵坐标都为奇数或者都为偶数时，要比较的点（即六边形中点分别为矩形左上点和右下点，否则为左下点和右上点）
    if (0 == (xIndex + yIndex) % 2) { // 都为奇数 或者 都为偶数
        pos1 = float2(lenght * width * xIndex,       lenght * height * yIndex);
        pos2 = float2(lenght * width * (xIndex + 1), lenght * height * (yIndex + 1));
    } else {   // 奇数和偶数
        pos1 = float2(lenght * width * xIndex,       lenght * height * (yIndex + 1));
        pos2 = float2(lenght * width * (xIndex + 1), lenght * height * yIndex);
    }
    // 算出当前像素点，相对 pos1、pos2 的距离
    float dis1 = sqrt(pow(pos1.x - input.textureCoordinate.x, 2.0) + pow(pos1.y - input.textureCoordinate.y, 2.0));
    float dis2 = sqrt(pow(pos2.x - input.textureCoordinate.x, 2.0) + pow(pos2.y - input.textureCoordinate.y, 2.0));
    
    float4 newColor;
    // 选择距离较近的点，读取其颜色
    if (dis1 < dis2) {
        newColor = colorTexure.sample(textureSampler, pos1);
    } else {
        newColor = colorTexure.sample(textureSampler, pos2);
    }
    
    return newColor;
}


