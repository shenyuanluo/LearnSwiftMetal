//
//  Transform.swift
//  LearnSwiftMetal
//
//  Created by ShenYuanLuo on 2022/6/15.
//

/*
 Metal 使用的是「列主序」矩阵和「列向量」输入
     linearIndex     cr              example with reference elements
      0  4  8 12     00 10 20 30     sx  10  20   tx
      1  5  9 13 --> 01 11 21 31 --> 01  sy  21   ty
      2  6 10 14     02 12 22 32     02  12  sz   tz
      3  7 11 15     03 13 23 33     03  13  1/d  33

 The "cr" names are for <column><row>
 */
enum SYTransform {
    
    
    /// 单位矩阵
    /// - Returns: 4x4 矩阵
    static func identityMatrix() -> simd_float4x4 {
        let col0 = SIMD4<Float>(1, 0, 0, 0)
        let col1 = SIMD4<Float>(0, 1, 0, 0)
        let col2 = SIMD4<Float>(0, 0, 1, 0)
        let col3 = SIMD4<Float>(0, 0, 0, 1)
        return .init(col0, col1, col2, col3)
    }
    
    /// 平移矩阵
    /// - Parameter translation: 平移向量
    /// - Returns: 4x4 矩阵
    static func translationMatrix(_ translation: SIMD3<Float>) -> simd_float4x4 {
        let col0 = SIMD4<Float>(1, 0, 0, 0)
        let col1 = SIMD4<Float>(0, 1, 0, 0)
        let col2 = SIMD4<Float>(0, 0, 1, 0)
        let col3 = SIMD4<Float>(translation, 1)
        return .init(col0, col1, col2, col3)
    }
    
    
    /// 旋转矩阵
    /// - Parameters:
    ///   - radians: 旋转半径
    ///   - axis: 旋转轴
    /// - Returns: 4x4 矩阵
    static func rotationMatrix(radians: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let normalizedAxis = simd_normalize(axis)   // 转成「单位」向量
        
        let ct = cosf(radians)
        let st = sinf(radians)
        let ci = 1 - ct
        let x = normalizedAxis.x
        let y = normalizedAxis.y
        let z = normalizedAxis.z
        
        let col0 = SIMD4<Float>(ct + x * x * ci,     y * x * ci + z * st, z * x * ci - y * st, 0)
        let col1 = SIMD4<Float>(x * y * ci - z * st, ct + y * y * ci,     z * y * ci + x * st, 0)
        let col2 = SIMD4<Float>(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci,     0)
        let col3 = SIMD4<Float>(0,                   0,                   0,                   1)
        
        return .init(col0, col1, col2, col3)
    }
    
    
    /// 缩放矩阵
    /// - Parameter scale: 缩放 3x3 向量
    /// - Returns: 4x4 矩阵
    static func scaleMatrix(_ scale: SIMD3<Float>) -> simd_float4x4 {
        let col0 = SIMD4<Float>(scale.x, 0,       0,       0)
        let col1 = SIMD4<Float>(0,       scale.y, 0,       0)
        let col2 = SIMD4<Float>(0,       0,       scale.z, 0)
        let col3 = SIMD4<Float>(0,       0,       0,       1)
        
        return .init(col0, col1, col2, col3)
    }
    
    
    /// 法线矩阵
    /// - Parameter modelMatrix: 4x4 矩阵
    /// - Returns: 3x3 矩阵
    static func normalMatrix(from modelMatrix: simd_float4x4) -> simd_float3x3 {
        let col0 = modelMatrix.columns.0.xyz
        let col1 = modelMatrix.columns.1.xyz
        let col2 = modelMatrix.columns.2.xyz
        return .init(col0, col1, col2)
    }

    
    /// 正交投影矩阵
    /// - Parameters:
    ///   - left: 左-边界
    ///   - right: 右-边界
    ///   - bottom: 下-边界
    ///   - top: 上-边界
    ///   - nearZ: 近-平面
    ///   - farZ: 远-平面
    /// - Returns: 4x4 矩阵
    static func orthographicProjection(_ left: Float,
                                       _ right: Float,
                                       _ bottom: Float,
                                       _ top: Float,
                                       _ nearZ: Float,
                                       _ farZ: Float) -> simd_float4x4 {

        let col0 = SIMD4<Float>(2 / (right - left),              0,                               0,                      0)
        let col1 = SIMD4<Float>(0,                               2 / (top - bottom),              0,                      0)
        let col2 = SIMD4<Float>(0,                               0,                               1 / (farZ - nearZ),     0)
        let col3 = SIMD4<Float>((left + right) / (left - right), (top + bottom) / (bottom - top), nearZ / (nearZ - farZ), 1)
        return .init(col0, col1, col2, col3)
    }

    
    /// 透视投影矩阵（左手坐标系）
    /// - Parameters:
    ///   - fovyRadians: 视野角度（弧度制）
    ///   - aspectRatio: 宽高比例
    ///   - nearZ: 近-平面
    ///   - farZ: 远-平面
    /// - Returns: 4x4 矩阵
    static func perspectiveProjection(_ fovyRadians: Float,
                                      _ aspectRatio: Float,
                                      _ nearZ: Float,
                                      _ farZ: Float) -> simd_float4x4 {
        let ys = 1 / tanf(fovyRadians * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (farZ - nearZ)

        let col0 = SIMD4<Float>(xs, 0,  0,          0)
        let col1 = SIMD4<Float>(0,  ys, 0,          0)
        let col2 = SIMD4<Float>(0,  0,  zs,         1)
        let col3 = SIMD4<Float>(0,  0, -nearZ * zs, 0)

        return .init(col0, col1, col2, col3)
    }

    
    /// 观察矩阵（左手坐标系）
    /// - Parameters:
    ///   - eye: 观察向量
    ///   - target: 目标向量
    ///   - up: 向上向量
    /// - Returns: 4x4 矩阵
    static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {

        let z = normalize(target - eye)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        let t = SIMD3<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye))

        let col0 = SIMD4<Float>(x.x, y.x, z.x, 0)
        let col1 = SIMD4<Float>(x.y, y.y, z.y, 0)
        let col2 = SIMD4<Float>(x.z, y.z, z.z, 0)
        let col3 = SIMD4<Float>(t.x, t.y, t.z, 1)

        return .init(col0, col1, col2, col3)
    }
    
    
    /// 角度转弧度
    /// - Parameter angle: 角度
    /// - Returns: 弧度
    static func radian(_ angle: Float) -> Float {
        return angle * Float(Float.pi / 180.0)
    }
    
    
    /// 弧度转角度
    /// - Parameter radian: 弧度
    /// - Returns: 角度
    static func angle(_ radian: Float) -> Float {
        return radian * Float(180 / Float.pi)
    }
    
}


extension SIMD4 {
    /// 便捷获取 4 维向量的前 3 分量
    var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}
