import Foundation
import UIKit
import UserNotifications

/// 睡前提醒：每天固定時間一則本機通知。不連網、不催、沒念也不會怎樣。
enum Reminder {
    static let identifier = "bedtime"
    static let defaultMinutes = 20 * 60
    static let body = "今晚念哪一本？"

    /// 一天裡的第幾分鐘 → 幾點幾分
    static func components(minutes: Int) -> DateComponents {
        let clamped = max(0, min(24 * 60 - 1, minutes))
        var c = DateComponents()
        c.hour = clamped / 60
        c.minute = clamped % 60
        return c
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func date(minutes: Int, calendar: Calendar = .current) -> Date {
        let c = components(minutes: minutes)
        return calendar.date(bySettingHour: c.hour ?? 20, minute: c.minute ?? 0, second: 0, of: Date()) ?? Date()
    }

    /// 跟 iPhone 要通知權限，拿到才排提醒。回傳有沒有成功。
    static func enable(minutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        schedule(minutes: minutes)
        return true
    }

    static func schedule(minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "蘿讀"
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components(minutes: minutes), repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// 使用者是不是在 iPhone 的設定裡把通知關掉了
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}

/// 觸覺回饋：念完輕輕一下，冒芽和拔起來重一點。
enum Haptics {
    static func leaf() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func sprout() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func pulled() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
