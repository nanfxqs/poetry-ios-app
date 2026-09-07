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
        XCTAssertTrue(app.staticTexts["相关作品"].waitForExistence(timeout: 5))
        XCTAssertTrue(poemLink.isHittable, "返回后保留相关作品处的阅读位置")
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
    func testAuthorWorksAndReturnPreserveReader() throws {
        app.launch()
        let author = app.buttons["reader-author"]
        XCTAssertTrue(author.waitForExistence(timeout: 15))
        author.tap()
        let works = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "poet-work-")).firstMatch
        reveal(works)
        let title = works.label
        works.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(works.waitForExistence(timeout: 5))
        XCTAssertTrue(works.isHittable)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(author.waitForExistence(timeout: 5))
    }

    func testOfflinePlaceListSelectionAndReaderReturn() throws {
        app.launch()
        app.tabBars.buttons["探索"].tap()
        let clear = app.buttons["清空条件"]
        if clear.exists && clear.isHittable { clear.tap() }
        let place = app.buttons["places.yangzhou"]
        reveal(place)
        place.tap()
        let poem = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "黄鹤楼送孟浩然之广陵")).firstMatch
        reveal(poem)
        poem.tap()
        XCTAssertTrue(app.staticTexts["故人西辞黄鹤楼，"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(poem.isHittable)
        for _ in 0..<10 {
            if app.buttons["places.clear"].isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(app.buttons["places.clear"].exists, "阅读返回保留地点筛选")
        app.buttons["places.clear"].tap()
    }

    func testLifeTimelineEvidenceAndReturnToPoet() throws {
        app.launch()
        let author = app.buttons["reader-author"]
        XCTAssertTrue(author.waitForExistence(timeout: 15))
        author.tap()
        let life = app.buttons["poet-life"]
        reveal(life)
        life.tap()
        let source = app.buttons["事件依据与时间说明"].firstMatch
        reveal(source)
        source.tap()
        reveal(app.staticTexts["《旧唐书》卷190下"])
        reveal(app.staticTexts["暂未建立有依据的作品关联。"].firstMatch)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(life.waitForExistence(timeout: 5))
        XCTAssertTrue(life.isHittable)
    }

    func testRelationshipEvidenceNavigationAndLargeTextList() throws {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let author = app.buttons["reader-author"]
        XCTAssertTrue(author.waitForExistence(timeout: 15))
        author.tap()
        let relations = app.buttons["人物关系"]
        reveal(relations)
        relations.tap()
        let edge = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "relation-edge-")).firstMatch
        reveal(edge)
        edge.tap()
        let evidence = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "relation-evidence-")).firstMatch
        reveal(evidence)
        evidence.tap()
        XCTAssertTrue(app.buttons["reader-author"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(evidence.waitForExistence(timeout: 5))
        XCTAssertTrue(evidence.isHittable, "返回后保留所选关系与证据位置")
    }

}
