import XCTest
@testable import InterviewTrackerLogic

final class StageClassifierTests: XCTestCase {
    func testNotStartedBucket() {
        XCTAssertEqual(StageClassifier.bucket(forTitle: "准备投"), .notStarted)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "官网投"), .notStarted)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "海投"), .notStarted)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "内推"), .notStarted)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "猎头联系Leslie"), .notStarted)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "Recruiter联系"), .notStarted)
    }

    func testInProgressBucket() {
        XCTAssertEqual(StageClassifier.bucket(forTitle: "预约HR Call"), .inProgress)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "HR Call"), .inProgress)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "Hiring Manager Chat"), .inProgress)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "预约Phone Interview 1"), .inProgress)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "Phone Interview 3"), .inProgress)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "Onsite 2"), .inProgress)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "技术电面一"), .inProgress)
    }

    func testClosedBucket() {
        XCTAssertEqual(StageClassifier.bucket(forTitle: "Offer"), .closed)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "拒绝"), .closed)
        XCTAssertEqual(StageClassifier.bucket(forTitle: "拒了"), .closed)
    }

    func testIsInterviewStartsAtHRCall() {
        XCTAssertTrue(StageClassifier.isInterview(forTitle: "HR Call"))
        XCTAssertTrue(StageClassifier.isInterview(forTitle: "HR Call 2"))
        XCTAssertTrue(StageClassifier.isInterview(forTitle: "Hiring Manager Chat"))
        XCTAssertTrue(StageClassifier.isInterview(forTitle: "HM Chat"))
        XCTAssertTrue(StageClassifier.isInterview(forTitle: "Phone Interview 3"))
        XCTAssertTrue(StageClassifier.isInterview(forTitle: "Onsite 1"))
        XCTAssertTrue(StageClassifier.isInterview(forTitle: "技术电面一"))
    }

    func testIsInterviewExcludesPreHRCallAndBookings() {
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "猎头联系Leslie"))
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "猎头Call"))
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "Recruiter联系"))
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "内推"))
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "官网投"))
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "预约HR Call"))
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "预约Phone Interview 1"))
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "Offer"))
        XCTAssertFalse(StageClassifier.isInterview(forTitle: "拒绝"))
    }

    func testFormatTitleKeepsUserWording() {
        XCTAssertEqual(StageClassifier.formatTitle("hr call"), "HR Call")
        XCTAssertEqual(StageClassifier.formatTitle("预约hr call"), "预约HR Call")
        XCTAssertEqual(StageClassifier.formatTitle("phone interview 2"), "Phone Interview 2")
        XCTAssertEqual(StageClassifier.formatTitle("猎头联系Leslie"), "猎头联系Leslie")
        XCTAssertEqual(StageClassifier.formatTitle("  内推  "), "内推")
        XCTAssertEqual(StageClassifier.formatTitle("onsite 1"), "Onsite 1")
    }
}

final class OpportunityBucketTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(OpportunityBucket.parse("not_started"), .notStarted)
        XCTAssertEqual(OpportunityBucket.parse("in_progress"), .inProgress)
        XCTAssertEqual(OpportunityBucket.parse("closed"), .closed)
        XCTAssertEqual(OpportunityBucket.parse("未开始"), .notStarted)
        XCTAssertEqual(OpportunityBucket.parse("进行中"), .inProgress)
        XCTAssertEqual(OpportunityBucket.parse("已结束"), .closed)
        XCTAssertNil(OpportunityBucket.parse("bogus"))
        XCTAssertNil(OpportunityBucket.parse(nil))
    }
}

final class ISO8601FlexibleTests: XCTestCase {
    func testHasClockTime() {
        XCTAssertTrue(ISO8601Flexible.hasClockTime("2026-07-15T15:00"))
        XCTAssertFalse(ISO8601Flexible.hasClockTime("2026-07-15"))
    }

    func testParseDayAndDateTime() {
        XCTAssertNotNil(ISO8601Flexible.parse("2026-07-15"))
        XCTAssertNotNil(ISO8601Flexible.parse("2026-07-15T15:00"))
        XCTAssertNil(ISO8601Flexible.parse("not a date"))
    }
}

final class CompanyNameNormalizerTests: XCTestCase {
    func testOfficialBranding() {
        XCTAssertEqual(CompanyNameNormalizer.canonicalize("deepseek"), "DeepSeek")
        XCTAssertEqual(CompanyNameNormalizer.canonicalize("moonshot"), "Moonshot（月之暗面）")
        XCTAssertEqual(CompanyNameNormalizer.canonicalize("nvidia"), "NVIDIA")
        XCTAssertEqual(CompanyNameNormalizer.canonicalize("sierra"), "Sierra")
    }

    func testWordPrefixMatchesShortNameToFullName() {
        // 短名认出带后缀的全名（防重复新建公司）。
        XCTAssertTrue(CompanyNameNormalizer.isWordPrefixMatch("sierra", "Sierra AI"))
        XCTAssertTrue(CompanyNameNormalizer.isWordPrefixMatch("Sierra AI", "sierra"))
        XCTAssertTrue(CompanyNameNormalizer.isWordPrefixMatch("google", "Google DeepMind"))
    }

    func testWordPrefixDoesNotMatchHalfWord() {
        // 不能把半个词当命中：open ≠ openai。
        XCTAssertFalse(CompanyNameNormalizer.isWordPrefixMatch("open", "openai"))
        XCTAssertFalse(CompanyNameNormalizer.isWordPrefixMatch("sierra", "sierraai"))
        // 完全相等不算「前缀模糊」（交给精确匹配那条路）。
        XCTAssertFalse(CompanyNameNormalizer.isWordPrefixMatch("sierra", "Sierra"))
    }
}
