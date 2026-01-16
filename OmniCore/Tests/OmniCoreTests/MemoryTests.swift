import XCTest
import Metal
@testable import OmniCore

final class MemoryTests: XCTestCase {
    
    func testGlobalHeapAllocation() {
        // Warning: This requires a Metal device. CI environments might fail if no GPU is present.
        // We wrap in a check.
        guard MTLCreateSystemDefaultDevice() != nil else {
            print("Skipping Heap Test: No Metal Device")
            return
        }
        
        // Accessing shared should trigger allocation
        let heap = GlobalHeap.shared.heap
        XCTAssertNotNil(heap)
        XCTAssertEqual(heap.size, 20 * 1024 * 1024)
        XCTAssertEqual(heap.storageMode, .private)
    }
    
    func testHeapSubAllocation() {
        guard MTLCreateSystemDefaultDevice() != nil else { return }
        
        let buffer = GlobalHeap.shared.allocateBuffer(length: 1024)
        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.length, 1024)
        #if !targetEnvironment(simulator)
        XCTAssertNotNil(buffer?.heap)
        // Check identity if possible, or just properties
        XCTAssertTrue(buffer?.heap === GlobalHeap.shared.heap)
        #endif
    }
    
    func testRingBufferCycling() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        
        // Test RingBuffer over Int32
        let ring = RingBuffer<Int32>(device: device, count: 3)
        
        let ptr1 = Unmanaged.passUnretained(ring.current).toOpaque()
        ring.next()
        let ptr2 = Unmanaged.passUnretained(ring.current).toOpaque()
        ring.next()
        let ptr3 = Unmanaged.passUnretained(ring.current).toOpaque()
        ring.next()
        let ptr4 = Unmanaged.passUnretained(ring.current).toOpaque()
        
        XCTAssertNotEqual(ptr1, ptr2)
        XCTAssertNotEqual(ptr2, ptr3)
        XCTAssertEqual(ptr1, ptr4, "Ring buffer should cycle back to start")
    }
}
