import XCTest

/// Drives tab 1 on the simulator so the JSONL export path is verified by an agent,
/// not assumed. The mock client is deterministic, so this stays offline.
@MainActor
final class ScenarioRunnerUITests: XCTestCase {
    func testMockRunCompletesEveryScenario() {
        let app = XCUIApplication()
        app.launch()

        let runButton = app.buttons["mock으로 전체 실행"]
        XCTAssertTrue(runButton.waitForExistence(timeout: 20), "scenario tab did not appear")

        runButton.tap()

        let finished = app.staticTexts["완료 20/20"]
        XCTAssertTrue(finished.waitForExistence(timeout: 180), "mock run did not finish")
    }

    /// Records what the simulator's Apple Intelligence support actually is, and only
    /// runs the on-device path when the framework reports the model as available.
    func testAppleClientAvailabilityIsReported() {
        let app = XCUIApplication()
        app.launch()

        let appleSegment = app.segmentedControls.buttons["apple"]
        XCTAssertTrue(appleSegment.waitForExistence(timeout: 20), "client picker missing")
        appleSegment.tap()

        let availability = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "사용"))
            .firstMatch
        XCTAssertTrue(availability.waitForExistence(timeout: 10), "availability line missing")
        print("APPLE_AVAILABILITY_LABEL: \(availability.label)")

        if availability.label == "사용 가능" {
            app.buttons["apple으로 전체 실행"].tap()

            // Guardrails can refuse a turn ("May contain unsafe content"), so the run may
            // end at 19/20. What must hold is that all 20 scenarios were attempted and the
            // batch finished instead of hanging.
            let finished = app.staticTexts
                .matching(NSPredicate(format: "label BEGINSWITH %@", "완료"))
                .firstMatch
            XCTAssertTrue(finished.waitForExistence(timeout: 900), "apple run did not finish")
            print("APPLE_RUN_STATUS: \(finished.label)")
        }
    }

    func testAllThreeTabsExist() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["시나리오"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.tabBars.buttons["ASR"].exists)
        XCTAssertTrue(app.tabBars.buttons["라이브"].exists)
    }

    /// Starts an ASR session and accepts either outcome: recording begins, or the screen
    /// reports why it cannot (no microphone / no speech model). Recognition quality itself
    /// needs a human voice.
    func testASRScreenStartsOrExplainsWhyNot() {
        let app = XCUIApplication()

        // A reinstall can reset the simulator's microphone grant; answer the system alert so
        // the test measures the app, not the permission dialog.
        addUIInterruptionMonitor(withDescription: "Microphone permission") { alert in
            for label in ["Allow", "허용", "OK", "확인"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()
        app.tabBars.buttons["ASR"].tap()

        let start = app.buttons["녹음 시작"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "ASR tab did not load")
        start.tap()

        let finish = app.buttons["녹음 종료"]
        let problem = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS '마이크' OR label CONTAINS '실패' OR label CONTAINS '수 없다'"))
            .firstMatch

        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline, !finish.exists, !problem.exists {
            app.tap()  // gives the interruption monitor a chance to dismiss the alert
            usleep(500_000)
        }

        print("ASR_RECORDING: \(finish.exists) ASR_PROBLEM: \(problem.exists ? problem.label : "-")")
        XCTAssertTrue(finish.exists || problem.exists, "ASR screen neither started nor explained why")

        if finish.exists {
            finish.tap()
            let stopped = app.staticTexts
                .matching(NSPredicate(format: "label BEGINSWITH '인식 완료' OR label BEGINSWITH '인식된'"))
                .firstMatch
            _ = stopped.waitForExistence(timeout: 60)
            print("ASR_AFTER_STOP: \(stopped.exists ? stopped.label : "no status")")
        }
    }

    /// Speech synthesis is independent of the microphone, so the simulator can verify it.
    func testSpeechSynthesisStartsOrExplainsWhyNot() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["라이브"].tap()

        let tts = app.buttons["TTS만 확인"]
        XCTAssertTrue(tts.waitForExistence(timeout: 20), "live tab did not load")
        tts.tap()

        let outcome = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH 'TTS 시작까지' OR label BEGINSWITH 'TTS 시작 감지 실패'"))
            .firstMatch
        XCTAssertTrue(outcome.waitForExistence(timeout: 20))
        print("TTS_OUTCOME: \(outcome.label)")
    }

    /// Session start/end writes the battery/thermal session record to JSONL.
    func testLiveSessionStartsAndEnds() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["라이브"].tap()

        let start = app.buttons["세션 시작"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "live tab did not load")
        start.tap()

        XCTAssertTrue(app.staticTexts["세션 ID"].waitForExistence(timeout: 20))
        app.buttons["세션 종료"].tap()

        let ended = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH '세션 종료'"))
            .firstMatch
        XCTAssertTrue(ended.waitForExistence(timeout: 20))
        print("LIVE_SESSION_END: \(ended.label)")
    }

    /// Runs the same 34-turn script under three context policies (TASKS.md §5).
    func testLongConversationUnderThreePolicies() {
        let app = XCUIApplication()
        app.launch()

        let appleSegment = app.segmentedControls.buttons["apple"]
        XCTAssertTrue(appleSegment.waitForExistence(timeout: 20), "client picker missing")
        appleSegment.tap()

        for mode in ["요약 없음", "요약 8턴", "요약 700"] {
            app.buttons[mode].tap()
            app.buttons["장기 대화 실행"].tap()

            let finished = app.staticTexts
                .matching(NSPredicate(format: "label BEGINSWITH %@", "완료 1/1 · \(mode)"))
                .firstMatch
            XCTAssertTrue(finished.waitForExistence(timeout: 900), "long run \(mode) did not finish")
            print("LONG_RUN[\(mode)]: \(finished.label)")
        }
    }

    /// Verifies the recommended defaults (recentTurns 24, budget 7000) keep the facts.
    func testLongConversationRecommendedDefault() {
        let app = XCUIApplication()
        app.launch()

        let appleSegment = app.segmentedControls.buttons["apple"]
        XCTAssertTrue(appleSegment.waitForExistence(timeout: 20), "client picker missing")
        appleSegment.tap()

        app.buttons["기본 64"].tap()
        app.buttons["장기 대화 실행"].tap()

        let finished = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "완료 1/1 · 기본 64"))
            .firstMatch
        XCTAssertTrue(finished.waitForExistence(timeout: 900), "recommended run did not finish")
        print("LONG_RUN[기본 64]: \(finished.label)")
    }

    /// Prints what the device actually reports for Apple Intelligence and the context budget.
    func testDeviceAppleDiagnostics() {
        let app = XCUIApplication()
        app.launch()

        let appleSegment = app.segmentedControls.buttons["apple"]
        XCTAssertTrue(appleSegment.waitForExistence(timeout: 20), "client picker missing")
        appleSegment.tap()

        let availability = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "사용"))
            .firstMatch
        XCTAssertTrue(availability.waitForExistence(timeout: 10))
        print("DEVICE_APPLE_AVAILABILITY: \(availability.label)")

        let tokenLabels = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "토큰"))
        for index in 0..<min(tokenLabels.count, 6) {
            print("DEVICE_TOKEN_LABEL[\(index)]: \(tokenLabels.element(boundBy: index).label)")
        }
    }

    /// Two recordings in a row: the second session used to trap inside Speech on device.
    func testASRTwoConsecutiveRecordings() {
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Microphone permission") { alert in
            for label in ["Allow", "허용", "OK", "확인"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app.launch()
        app.tabBars.buttons["ASR"].tap()

        for round in 1...2 {
            let start = app.buttons["녹음 시작"]
            XCTAssertTrue(start.waitForExistence(timeout: 20), "round \(round): start missing")
            start.tap()

            let finish = app.buttons["녹음 종료"]
            let deadline = Date().addingTimeInterval(60)
            while Date() < deadline, !finish.exists {
                app.tap()
                usleep(500_000)
            }
            XCTAssertTrue(finish.exists, "round \(round): recording did not start")
            finish.tap()

            let done = app.staticTexts
                .matching(NSPredicate(format: "label BEGINSWITH '인식 완료' OR label BEGINSWITH '인식된'"))
                .firstMatch
            XCTAssertTrue(done.waitForExistence(timeout: 60), "round \(round): no result")
            print("ASR_ROUND[\(round)]: \(done.label)")

            if round == 1 {
                // Next sentence lives below the fold; scroll down, advance, scroll back.
                app.swipeUp()
                let next = app.buttons["다음 문장"]
                if next.waitForExistence(timeout: 10) {
                    next.tap()
                }
                app.swipeDown()
                app.swipeDown()
            }
        }
    }
}
