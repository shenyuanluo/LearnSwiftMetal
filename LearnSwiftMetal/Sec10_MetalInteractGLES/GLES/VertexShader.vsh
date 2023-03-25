//
//  VertexShader.vsh
//  Sec10_MetalInteractGLES
//
//  Created by ShenYuanLuo on 2022/5/27.
//


/*
 顶点着色器
 */

attribute vec4 position;    // 顶点-位置（attribute 修饰表示只能在「顶点」着色器使用）
attribute vec2 texCoord;    // 纹理-坐标（attribute 修饰表示只能在「顶点」着色器使用）
varying vec2 texCoordVarying;   // 纹理坐标（输出给「片段」着色器）（varying 修饰表示「顶点」着色器传给「片段」着色器）

void main()
{
    gl_Position     = position; // 设置顶点位置
    texCoordVarying = texCoord; // 设置纹理坐标
}
