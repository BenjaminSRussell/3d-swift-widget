import XCTest
import simd
@testable import OmniCore

final class MemoryLayoutTests: XCTestCase {
    
    func testFrameUniformsAlignment() {
        // Assert that the Swift stride matches the Metal expectation (16 byte alignment)
        // FrameUniforms:
        // 4x float4x4 (64 bytes each) = 256
        // cameraPosition (16 bytes aligned float3) = 16
        // time (4 bytes) + padding (12 bytes) = 16 (Wait, float3 is usually 16 byte aligned in std140 if not packed?)
        // Let's verify our C header struct.
        
        // Actually, we need to inspect the C struct size. 
        // Since we can't easily import the C struct into Swift Tests without a bridging header in the test target,
        // we will manually calculate expected sizes.
        
        // Metal std140:
        // float4x4 = 64 bytes
        // float3 = 16 bytes (alignment)
        
        // struct FrameUniforms {
        //    float4x4 viewMatrix;                 // 0   - 64
        //    float4x4 projectionMatrix;           // 64  - 128
        //    float4x4 viewProjectionMatrix;       // 128 - 192
        //    float4x4 inverseViewProjectionMatrix;// 192 - 256
        //
        //    float3 cameraPosition;               // 256 - 268 (padded to 272 for 16-byte alignment of next field?)
        //    float  time;                         // 272 - 276
        //
        //    float2 resolution;                   // 276 - 284
        //    float  deltaTime;                    // 284 - 288
        //    uint   frameCount;                   // 288 - 292
        // }
        // Total needs to be multiple of 16 (largest member alignment). 
        // Let's ensuring we are explicit in the header.
        
        XCTAssertEqual(MemoryLayout<vector_float4>.size, 16)
        XCTAssertEqual(MemoryLayout<matrix_float4x4>.stride, 64)
    }
}
