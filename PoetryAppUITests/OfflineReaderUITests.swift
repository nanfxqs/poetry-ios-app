import XCTest

/// Run with the device offline to verify that every reading action stays local.
/// These tests preserve the installation and never erase the user's database.
final class OfflineReaderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    }

    private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<18 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Cannot reach \(element)", file: file, line: line)
    }

    func testOfflineReadSourcesNavigateAndRestart() throws {
        app.launch()
        XCTAssertTrue(app.staticTexts["黄鹤楼送孟浩然之广陵"].waitForExistence(timeout: 15))
        for text in ["故人西辞黄鹤楼，", "烟花三月下扬州。", "孤帆远影碧空尽，", "唯见长江天际流。"] {
            reveal(app.staticTexts[text])
        }
        let sources = app.buttons["来源与版本"]
        reveal(sources)
        sources.tap()
        reveal(app.staticTexts["《全唐诗》古诗原文 · 维基文库核对入口"])
        reveal(app.staticTexts["古代作品原文属于公有领域；本包不收录现代译注或页面编辑说明。"])
        // Do not open the external source webpage: its citation must remain readable offline.
        let poemLink = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "赠孟浩然")).firstMatch
        reveal(poemLink)
        poemLink.tap()
        XCTAssertTrue(app.staticTexts["赠孟浩然"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["高山安可仰，徒此揖清芬。"])
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["随包作品"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["黄鹤楼送孟浩然之广陵"].waitForExistence(timeout: 10))
    }

    func testAccessibilityTextSizeCanReachEndOfReadingAndSources() throws {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["黄鹤楼送孟浩然之广陵"].waitForExistence(timeout: 15))
        reveal(app.staticTexts["唯见长江天际流。"])
        let sources = app.buttons["来源与版本"]
        reveal(sources)
        sources.tap()
        reveal(app.staticTexts["《全唐诗》古诗原文 · 维基文库核对入口"])
        XCTAssertTrue(app.tabBars.buttons["今日"].isHittable)
        XCTAssertTrue(app.tabBars.buttons["探索"].isHittable)
        XCTAssertTrue(app.tabBars.buttons["诗集"].isHittable)
    }
}
