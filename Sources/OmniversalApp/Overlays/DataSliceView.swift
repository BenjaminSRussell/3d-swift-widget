import SwiftUI
import Charts

struct DataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let sigma: Double
}

public struct DataSliceView: View {
    // Mock data for demo - in real app would read from DataActor
    let data: [DataPoint] = (0..<100).map { i in
        let x = Double(i) / 10.0
        return DataPoint(
            x: x, 
            y: sin(x) + Double.random(in: -0.1...0.1), 
            sigma: 0.2 + abs(cos(x)) * 0.1
        )
    }
    
    public init() {}
    
    public var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("X", point.x),
                y: .value("Y", point.y)
            )
            .foregroundStyle(.blue)
            
            AreaMark(
                x: .value("X", point.x),
                yStart: .value("Lower", point.y - point.sigma * 2), // 2 Sigma
                yEnd: .value("Upper", point.y + point.sigma * 2)
            )
            .foregroundStyle(.blue.opacity(0.1))
        }
        .frame(height: 200)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding()
    }
}
