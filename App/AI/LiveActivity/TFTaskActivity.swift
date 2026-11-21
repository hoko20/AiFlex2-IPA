import ActivityKit
import Foundation

@available(iOS 16.2, *)
public struct TFTaskAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var stage: String
        public var count: Int
        public var steps: Int
        public var finished: Bool
    }
    public var startedAt: Date
}

@available(iOS 16.2, *)
@objc(TFTaskLiveActivity)
public final class TFTaskLiveActivity: NSObject {
    private static var current: Activity<TFTaskAttributes>?
    private static var desired: TFTaskAttributes.ContentState?
    private static var generation: Int = 0
    @objc public private(set) static var status: String = "尚未启动实时活动"
    @objc public static func update(_ stage: String, count: Int, steps: Int) {
        let state = TFTaskAttributes.ContentState(stage: String(stage.prefix(56)), count: count, steps: steps, finished: false)
        desired = state
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { status = "系统实时活动权限未开启"; return }
        if current == nil {
            // Reconcile stale activities after a previous process ended.
            let old = Activity<TFTaskAttributes>.activities
            Task { for activity in old { await activity.end(nil, dismissalPolicy: .immediate) } }
            do { current = try Activity.request(attributes: TFTaskAttributes(startedAt: Date()), content: ActivityContent(state: state, staleDate: nil), pushType: nil); status = "实时活动已启动" }
            catch { status = "实时活动启动失败：" + error.localizedDescription; NSLog("[AI Live Activity] %@", error.localizedDescription) }
        } else if let activity = current {
            generation += 1
            let revision = generation
            Task { @MainActor in
                guard revision == generation, let latest = desired else { return }
                await activity.update(ActivityContent(state: latest, staleDate: nil))
            }
        }
    }
    @objc public static func finish(_ success: Bool) {
        desired = nil
        generation += 1
        let state = TFTaskAttributes.ContentState(stage: success ? "处理完成" : "请查看会话", count: 0, steps: 0, finished: true)
        let currentActivity = current
        current = nil
        // 结束当前实例之外，还要清掉上一个进程遗留的实例：静态变量在重启后是 nil，
        // 只结束 current 会让旧实时活动一直挂在灵动岛/锁屏上，开关关掉也清不掉。
        let stale = Activity<TFTaskAttributes>.activities
        Task {
            if let currentActivity {
                await currentActivity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(8)))
            }
            for other in stale where other.id != currentActivity?.id {
                await other.end(nil, dismissalPolicy: .immediate)
            }
        }
        status = "实时活动已结束"
    }

    /// 仅做清理：把系统里所有属于本 App 的实时活动立即结束，不依赖内存里的 current。
    /// 用于开关关闭、以及上次异常退出后的启动自检。
    @objc public static func endAll() {
        desired = nil
        generation += 1
        current = nil
        let stale = Activity<TFTaskAttributes>.activities
        Task { for activity in stale { await activity.end(nil, dismissalPolicy: .immediate) } }
        status = "实时活动已关闭"
    }
}
