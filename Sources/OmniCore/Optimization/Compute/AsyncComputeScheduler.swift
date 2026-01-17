import Foundation

/// **The Compute Sub-System (The Logic Sub-System)**
///
/// A priority queue that lets you run heavy math (Topography) on a background thread
/// without freezing the UI.
public protocol AsyncComputeScheduler {
    /// Schedules a heavy compute task on a background thread.
    /// - Parameter priority: The priority of the task.
    /// - Parameter task: The closure to execute.
    /// - Parameter completion: The closure to execute on the main thread upon completion.
    func scheduleTask(priority: TaskPriority, task: @escaping () -> Void, completion: @escaping () -> Void)

    /// Cancels all pending tasks with a priority lower than the specified threshold.
    /// - Parameter threshold: The priority threshold below which tasks should be cancelled.
    func cancelTasks(below threshold: TaskPriority)
}

public enum TaskPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
