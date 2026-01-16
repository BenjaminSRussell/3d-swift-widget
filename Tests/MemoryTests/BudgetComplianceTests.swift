import XCTest
import Metal
@testable import OmniCoordinator

/// Test suite for memory budget enforcement and heap aliasing
final class BudgetComplianceTests: XCTestCase {
    
    var device: MTLDevice!
    var memoryManager: MemoryManager!
    
    override func setUp() {
        super.setUp()
        device = MTLCreateSystemDefaultDevice()!
        memoryManager = MemoryManager(device: device)
    }
    
    override func tearDown() {
        memoryManager = nil
        device = nil
        super.tearDown()
    }
    
    // MARK: - Budget Compliance Tests
    
    func testHeapAllocationUnder30MB() throws {
        // Test that heap allocation stays under 30MB limit
        let sizes = [
            5 * 1024 * 1024,  // 5MB
            8 * 1024 * 1024,  // 8MB
            7 * 1024 * 1024   // 7MB
        ]
        
        let buffers = memoryManager.allocateComputeBuffers(sizes: sizes)
        
        XCTAssertEqual(buffers.count, 3, "Should allocate 3 buffers")
        
        let totalUsage = memoryManager.currentMemoryUsage()
        XCTAssertLessThanOrEqual(totalUsage, MemoryManager.widgetMemoryBudget,
                                 "Total memory usage should be under 30MB")
        
        memoryManager.reportMemoryUsage()
        
        // Verify heap usage is reasonable (should be ~20MB due to aliasing)
        XCTAssertLessThanOrEqual(totalUsage, 25 * 1024 * 1024,
                                 "Heap usage should be under 25MB with aliasing")
    }
    
    func testMemorylessTexturesZeroRAM() throws {
        // Verify memoryless textures don't contribute to memory budget
        let initialUsage = memoryManager.currentMemoryUsage()
        
        let depthTexture = memoryManager.createMemorylessDepth(width: 1024, height: 1024)
        let msaaTexture = memoryManager.createMemorylessMSAA(width: 1024, height: 1024, sampleCount: 4)
        
        XCTAssertNotNil(depthTexture, "Depth texture should be created")
        XCTAssertNotNil(msaaTexture, "MSAA texture should be created")
        
        let finalUsage = memoryManager.currentMemoryUsage()
        
        // Memoryless textures should add 0 bytes
        XCTAssertEqual(initialUsage, finalUsage,
                      "Memoryless textures should not increase memory usage")
    }
    
    func testResourceAliasing() throws {
        // Test that compute and render resources share memory via aliasing
        
        // Phase 1: Allocate compute buffers
        let computeSizes = [10 * 1024 * 1024] // 10MB
        let computeBuffers = memoryManager.allocateComputeBuffers(sizes: computeSizes)
        
        let afterComputeUsage = memoryManager.currentMemoryUsage()
        XCTAssertGreaterThan(afterComputeUsage, 0, "Should have memory allocated")
        
        // Phase 2: Allocate render textures (should reuse memory)
        let textureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 512,
            height: 512,
            mipmapped: false
        )
        
        let renderTextures = memoryManager.allocateRenderTextures(descriptors: [textureDesc])
        
        let afterRenderUsage = memoryManager.currentMemoryUsage()
        
        // Aliasing should keep total usage reasonable
        XCTAssertLessThanOrEqual(afterRenderUsage, 20 * 1024 * 1024,
                                 "Aliasing should keep total under 20MB")
        
        // Validate aliasing
        XCTAssertTrue(memoryManager.validateAliasing(),
                     "Resource aliasing should be valid")
    }
    
    func testMemoryPressureHandling() throws {
        // Test automatic quality reduction under memory pressure
        
        // Allocate large shared buffer to trigger pressure
        let largeSize = 25 * 1024 * 1024 // 25MB
        let buffer = memoryManager.createSharedBuffer(size: largeSize)
        
        XCTAssertNotNil(buffer, "Buffer should be allocated")
        
        let usage = memoryManager.currentMemoryUsage()
        XCTAssertGreaterThan(usage, 20 * 1024 * 1024, "Should have significant usage")
        
        // Quality scale should be reduced if pressure was triggered
        let qualityScale = memoryManager.getQualityScale()
        XCTAssertGreaterThan(qualityScale, 0.0, "Quality scale should be positive")
        XCTAssertLessThanOrEqual(qualityScale, 1.0, "Quality scale should be ≤ 1.0")
        
        memoryManager.reportMemoryUsage()
    }
    
    func testBudgetEnforcement() throws {
        // Test that budget enforcement throws when limit is exceeded
        
        memoryManager.setMemoryBudgetEnabled(true)
        
        // Try to allocate more than budget allows
        let excessiveSize = 35 * 1024 * 1024 // 35MB (exceeds 30MB limit)
        
        XCTAssertThrowsError(try memoryManager.enforceMemoryBudget(additionalSize: excessiveSize)) { error in
            guard case MemoryError.budgetExceeded = error else {
                XCTFail("Expected budgetExceeded error")
                return
            }
        }
    }
    
    func testAllocationTimeline() throws {
        // Test that allocation history is tracked correctly
        
        let buffer1 = memoryManager.createSharedBuffer(size: 1024)
        let buffer2 = memoryManager.createSharedBuffer(size: 2048)
        
        let timeline = memoryManager.exportAllocationTimeline()
        
        XCTAssertGreaterThanOrEqual(timeline.count, 2, "Should have at least 2 allocations")
        
        // Verify timeline entries
        for entry in timeline {
            XCTAssertGreaterThan(entry.size, 0, "Size should be positive")
            XCTAssertFalse(entry.type.isEmpty, "Type should not be empty")
        }
    }
    
    // MARK: - Performance Tests
    
    func testAllocationPerformance() throws {
        // Measure allocation performance
        measure {
            let sizes = Array(repeating: 1024 * 1024, count: 10) // 10x 1MB
            _ = memoryManager.allocateComputeBuffers(sizes: sizes)
        }
    }
    
    func testMemoryReportPerformance() throws {
        // Ensure memory reporting is fast
        measure {
            memoryManager.reportMemoryUsage()
        }
    }
}
