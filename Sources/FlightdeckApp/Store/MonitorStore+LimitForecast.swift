import Foundation
import MonitorCore

extension MonitorStore {
    func limitForecast(for tool: AgentTool, window: UsageWindow) -> LimitForecast? {
        usageHistory.forecast(tool: tool, window: window)
    }
}
