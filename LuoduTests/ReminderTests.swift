import XCTest
@testable import Luodu

final class ReminderTests: XCTestCase {
    func testDefaultIsEightPM() {
        let c = Reminder.components(minutes: Reminder.defaultMinutes)
        XCTAssertEqual(c.hour, 20)
        XCTAssertEqual(c.minute, 0)
    }

    func testComponents() {
        XCTAssertEqual(Reminder.components(minutes: 19 * 60 + 45).hour, 19)
        XCTAssertEqual(Reminder.components(minutes: 19 * 60 + 45).minute, 45)
        XCTAssertEqual(Reminder.components(minutes: 0).hour, 0)
    }

    func testOutOfRangeIsClamped() {
        XCTAssertEqual(Reminder.components(minutes: -5).hour, 0)
        XCTAssertEqual(Reminder.components(minutes: 99999).hour, 23)
        XCTAssertEqual(Reminder.components(minutes: 99999).minute, 59)
    }

    func testMinutesAndDateRoundTrip() {
        for minutes in [0, 7 * 60 + 5, 20 * 60, 23 * 60 + 59] {
            XCTAssertEqual(Reminder.minutes(from: Reminder.date(minutes: minutes)), minutes)
        }
    }

    func testBodyDoesNotNag() {
        XCTAssertEqual(Reminder.body, "今晚念哪一本？")
    }
}
