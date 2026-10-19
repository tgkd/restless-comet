import Foundation
import Testing
@testable import RestlessCore

@MainActor
struct CoordinatorQueueTests {
    private let selfBundleID = CoordinatorFixture.selfBundleID
    private let ownApp = CoordinatorFixture.ownApp
    private let safari = CoordinatorFixture.safari
    private let chrome = CoordinatorFixture.chrome
    private let firefox = CoordinatorFixture.firefox

    @Test func directOpenCallsOpenerAndNeverPicker() async throws {
        let config = Config(defaultBrowser: safari.bundleID)
        let harness = CoordinatorHarness(installed: [ownApp, safari, chrome], config: config)
        let request = try makeRequest("https://example.com/direct")
        harness.router.decisions[request.id] = .open(bundleID: safari.bundleID, reason: .defaultBrowser)

        harness.coordinator.handle(request)
        #expect(harness.coordinator.pendingCount == 0)
        await harness.coordinator.settle()

        let expectedCalls = [CoordinatorFakeOpener.Call(url: request.url, bundleID: safari.bundleID)]
        let expectedRoutes = [
            CoordinatorRouteStub.Call(requestID: request.id, config: config, selfBundleID: selfBundleID)
        ]
        #expect(harness.opener.calls == expectedCalls)
        #expect(harness.router.calls == expectedRoutes)
        #expect(harness.configSource.reads == 1)
        #expect(harness.picker.events.isEmpty)
        #expect(harness.coordinator.pendingCount == 0)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func missingTargetShowsTargetUnavailableWithInstalledBrowsers() async throws {
        let harness = CoordinatorHarness(installed: [ownApp, safari, chrome], config: Config())
        let request = try makeRequest("https://example.com/missing")
        harness.router.decisions[request.id] = .open(bundleID: firefox.bundleID, reason: .rule(UUID()))

        harness.coordinator.handle(request)
        await harness.coordinator.settle()

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(request, [safari, chrome], .targetUnavailable(bundleID: firefox.bundleID), pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.opener.calls.isEmpty)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func openFailureShowsOpenFailedWithoutTheFailedBrowser() async throws {
        let harness = CoordinatorHarness(
            installed: [safari, ownApp, chrome, firefox],
            config: Config(),
            failing: [chrome.bundleID]
        )
        let request = try makeRequest("https://example.com/fails")
        harness.router.decisions[request.id] = .open(bundleID: chrome.bundleID, reason: .rule(UUID()))

        harness.coordinator.handle(request)
        #expect(harness.picker.events.isEmpty)
        await harness.coordinator.settle()

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(request, [safari, firefox], .openFailed(bundleID: chrome.bundleID), pending: 1))
        ]
        #expect(harness.opener.calls.map(\.bundleID) == [chrome.bundleID])
        #expect(harness.picker.events == expected)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func promptChoicesFollowShownBrowsersSkippingMissingAndSelf() throws {
        let shownBrowsers = [
            firefox.bundleID,
            "org.example.missing",
            selfBundleID,
            safari.bundleID,
            firefox.bundleID
        ]
        let harness = CoordinatorHarness(
            installed: [ownApp, safari, chrome, firefox],
            config: Config(shownBrowsers: shownBrowsers)
        )
        let request = try makeRequest("https://example.com/prompt")

        harness.coordinator.handle(request)

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(request, [firefox, safari], nil, pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test(arguments: [[String](), ["org.example.missing", CoordinatorFixture.selfBundleID]])
    func promptFallsBackToAllInstalledBrowsers(shownBrowsers: [String]) throws {
        let harness = CoordinatorHarness(
            installed: [safari, ownApp, chrome],
            config: Config(shownBrowsers: shownBrowsers)
        )
        let request = try makeRequest("https://example.com/fallback")

        harness.coordinator.handle(request)

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(request, [safari, chrome], nil, pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func nilConfigShowsConfigUnavailableWithAllInstalledBrowsers() throws {
        let harness = CoordinatorHarness(installed: [ownApp, safari, chrome], config: nil)
        let request = try makeRequest("https://example.com/no-config")

        harness.coordinator.handle(request)

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(request, [safari, chrome], .configUnavailable, pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.router.calls.isEmpty)
        #expect(harness.configSource.reads == 1)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func emptyCatalogStillShowsThePresentation() throws {
        let harness = CoordinatorHarness(installed: [], config: Config(shownBrowsers: [safari.bundleID]))
        let request = try makeRequest("https://example.com/nothing-installed")

        harness.coordinator.handle(request)

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(request, [], nil, pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func queuedRequestsWaitInOrderAndCloseAfterTheLast() throws {
        let harness = CoordinatorHarness(
            installed: [safari, chrome],
            config: Config(shownBrowsers: [safari.bundleID, chrome.bundleID])
        )
        let first = try makeRequest("https://example.com/first")
        let second = try makeRequest("https://example.com/second")
        let third = try makeRequest("https://example.com/third")

        harness.coordinator.handle(first)
        #expect(harness.coordinator.pendingCount == 1)
        harness.coordinator.handle(second)
        harness.coordinator.handle(third)
        #expect(harness.coordinator.pendingCount == 3)
        let afterIntake: [CoordinatorFakePicker.Event] = [
            .show(presentation(first, [safari, chrome], nil, pending: 1)),
            .updatePendingCount(2),
            .updatePendingCount(3)
        ]
        #expect(harness.picker.events == afterIntake)

        harness.picker.deliver(.cancel)
        #expect(harness.coordinator.pendingCount == 2)
        harness.picker.deliver(.cancel)
        #expect(harness.coordinator.pendingCount == 1)
        harness.picker.deliver(.cancel)
        #expect(harness.coordinator.pendingCount == 0)

        let expected: [CoordinatorFakePicker.Event] = afterIntake + [
            .show(presentation(second, [safari, chrome], nil, pending: 2)),
            .show(presentation(third, [safari, chrome], nil, pending: 1)),
            .close
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func choseOpensTheRequestInTheChosenBrowser() async throws {
        let harness = CoordinatorHarness(
            installed: [safari, chrome],
            config: Config(shownBrowsers: [safari.bundleID, chrome.bundleID])
        )
        let request = try makeRequest("https://example.com/choose")

        harness.coordinator.handle(request)
        harness.picker.deliver(.chose(bundleID: chrome.bundleID))
        #expect(harness.coordinator.pendingCount == 0)
        await harness.coordinator.settle()

        let expectedCalls = [CoordinatorFakeOpener.Call(url: request.url, bundleID: chrome.bundleID)]
        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(request, [safari, chrome], nil, pending: 1)),
            .close
        ]
        #expect(harness.opener.calls == expectedCalls)
        #expect(harness.picker.events == expected)
        #expect(harness.coordinator.pendingCount == 0)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func failureAfterChoseIsPresentedBeforeOlderWaitingRequests() async throws {
        let harness = CoordinatorHarness(
            installed: [safari, chrome, firefox],
            config: Config(shownBrowsers: [safari.bundleID, chrome.bundleID]),
            failing: [chrome.bundleID]
        )
        let first = try makeRequest("https://example.com/first")
        let second = try makeRequest("https://example.com/second")
        let third = try makeRequest("https://example.com/third")
        harness.coordinator.handle(first)
        harness.coordinator.handle(second)
        harness.coordinator.handle(third)

        harness.picker.deliver(.chose(bundleID: chrome.bundleID))
        #expect(harness.opener.calls.isEmpty)
        #expect(harness.coordinator.pendingCount == 2)

        await harness.coordinator.settle()
        #expect(harness.opener.calls.map(\.bundleID) == [chrome.bundleID])
        #expect(harness.coordinator.pendingCount == 3)

        harness.picker.deliver(.cancel)
        harness.picker.deliver(.cancel)
        harness.picker.deliver(.cancel)

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(first, [safari, chrome], nil, pending: 1)),
            .updatePendingCount(2),
            .updatePendingCount(3),
            .show(presentation(second, [safari, chrome], nil, pending: 2)),
            .updatePendingCount(3),
            .show(presentation(first, [safari, firefox], .openFailed(bundleID: chrome.bundleID), pending: 2)),
            .show(presentation(third, [safari, chrome], nil, pending: 1)),
            .close
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.coordinator.pendingCount == 0)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func directOpenFailureWaitsAtTheFrontWhileAnotherRequestIsShown() async throws {
        let harness = CoordinatorHarness(
            installed: [safari, chrome],
            config: Config(shownBrowsers: [safari.bundleID, chrome.bundleID]),
            failing: [chrome.bundleID]
        )
        let onScreen = try makeRequest("https://example.com/on-screen")
        let failing = try makeRequest("https://example.com/direct")
        let waiting = try makeRequest("https://example.com/waiting")
        harness.router.decisions[failing.id] = .open(bundleID: chrome.bundleID, reason: .alternative)

        harness.coordinator.handle(onScreen)
        harness.coordinator.handle(failing)
        harness.coordinator.handle(waiting)
        #expect(harness.coordinator.pendingCount == 2)
        await harness.coordinator.settle()
        #expect(harness.coordinator.pendingCount == 3)

        harness.picker.deliver(.cancel)
        harness.picker.deliver(.cancel)
        harness.picker.deliver(.cancel)

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(onScreen, [safari, chrome], nil, pending: 1)),
            .updatePendingCount(2),
            .updatePendingCount(3),
            .show(presentation(failing, [safari], .openFailed(bundleID: chrome.bundleID), pending: 2)),
            .show(presentation(waiting, [safari, chrome], nil, pending: 1)),
            .close
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func copiedAndCancelFinishOnlyTheCurrentRequest() async throws {
        let harness = CoordinatorHarness(installed: [safari], config: Config())
        let copied = try makeRequest("https://example.com/copy")
        let cancelled = try makeRequest("https://example.com/cancel")
        let remaining = try makeRequest("https://example.com/remaining")
        harness.coordinator.handle(copied)
        harness.coordinator.handle(cancelled)
        harness.coordinator.handle(remaining)

        harness.picker.deliver(.copied)
        #expect(harness.coordinator.pendingCount == 2)
        harness.picker.deliver(.cancel)
        #expect(harness.coordinator.pendingCount == 1)
        await harness.coordinator.settle()

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(copied, [safari], nil, pending: 1)),
            .updatePendingCount(2),
            .updatePendingCount(3),
            .show(presentation(cancelled, [safari], nil, pending: 2)),
            .show(presentation(remaining, [safari], nil, pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.opener.calls.isEmpty)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func cancelAllDropsEveryWaitingRequestAndCloses() async throws {
        let harness = CoordinatorHarness(installed: [safari], config: Config())
        let first = try makeRequest("https://example.com/1")
        let second = try makeRequest("https://example.com/2")
        let third = try makeRequest("https://example.com/3")
        let later = try makeRequest("https://example.com/later")
        harness.coordinator.handle(first)
        harness.coordinator.handle(second)
        harness.coordinator.handle(third)

        harness.picker.deliver(.cancelAll)
        #expect(harness.coordinator.pendingCount == 0)
        harness.coordinator.handle(later)
        await harness.coordinator.settle()

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(first, [safari], nil, pending: 1)),
            .updatePendingCount(2),
            .updatePendingCount(3),
            .close,
            .show(presentation(later, [safari], nil, pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.opener.calls.isEmpty)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func cancelAllKeepsInFlightOpensAndPresentsTheirLaterFailure() async throws {
        let harness = CoordinatorHarness(installed: [safari, chrome], config: Config(), failing: [chrome.bundleID])
        let opening = try makeRequest("https://example.com/opening")
        let onScreen = try makeRequest("https://example.com/on-screen")
        let waiting = try makeRequest("https://example.com/waiting")
        harness.router.decisions[opening.id] = .open(bundleID: chrome.bundleID, reason: .defaultBrowser)
        harness.coordinator.handle(opening)
        harness.coordinator.handle(onScreen)
        harness.coordinator.handle(waiting)

        harness.picker.deliver(.cancelAll)
        #expect(harness.coordinator.pendingCount == 0)
        await harness.coordinator.settle()

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(onScreen, [safari, chrome], nil, pending: 1)),
            .updatePendingCount(2),
            .close,
            .show(presentation(opening, [safari], .openFailed(bundleID: chrome.bundleID), pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func duplicateOutcomeIsIgnored() async throws {
        let harness = CoordinatorHarness(installed: [safari, chrome], config: Config())
        let first = try makeRequest("https://example.com/first")
        let second = try makeRequest("https://example.com/second")
        harness.coordinator.handle(first)
        harness.coordinator.handle(second)
        harness.picker.deliver(.cancel)
        let afterOutcome = harness.picker.events

        harness.picker.redeliver(.cancel, toShowAt: 0)
        harness.picker.redeliver(.chose(bundleID: safari.bundleID), toShowAt: 0)
        harness.picker.redeliver(.cancelAll, toShowAt: 0)
        await harness.coordinator.settle()

        #expect(harness.picker.events == afterOutcome)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.opener.calls.isEmpty)

        harness.picker.deliver(.cancel)
        let finished: [CoordinatorFakePicker.Event] = afterOutcome + [.close]
        #expect(harness.picker.events == finished)
        #expect(harness.coordinator.pendingCount == 0)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func staleOutcomeFromAnEarlierPresentationOfTheSameRequestIsIgnored() async throws {
        let harness = CoordinatorHarness(
            installed: [safari, chrome],
            config: Config(shownBrowsers: [safari.bundleID, chrome.bundleID]),
            failing: [chrome.bundleID]
        )
        let request = try makeRequest("https://example.com/retry")
        harness.coordinator.handle(request)
        harness.picker.deliver(.chose(bundleID: chrome.bundleID))
        await harness.coordinator.settle()
        let represented: [CoordinatorFakePicker.Event] = [
            .show(presentation(request, [safari, chrome], nil, pending: 1)),
            .close,
            .show(presentation(request, [safari], .openFailed(bundleID: chrome.bundleID), pending: 1))
        ]
        #expect(harness.picker.events == represented)

        harness.picker.redeliver(.cancel, toShowAt: 0)
        harness.picker.redeliver(.chose(bundleID: safari.bundleID), toShowAt: 0)
        await harness.coordinator.settle()
        #expect(harness.picker.events == represented)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.opener.calls.map(\.bundleID) == [chrome.bundleID])

        harness.picker.deliver(.chose(bundleID: safari.bundleID))
        await harness.coordinator.settle()
        let finished: [CoordinatorFakePicker.Event] = represented + [.close]
        #expect(harness.opener.calls.map(\.bundleID) == [chrome.bundleID, safari.bundleID])
        #expect(harness.picker.events == finished)
        #expect(harness.coordinator.pendingCount == 0)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func openerReceivesTheOriginalURLByteForByte() async throws {
        let directString = "https://Example.COM:8443/a%2Fb/%7Euser/caf%C3%A9?q=a+b&x=%2f%2F&empty=&flag#frag%20ment/x?y"
        let chosenString = "http://example.org/path;params/./../%25?next=https%3A%2F%2Fother.example%2F%3Fa%3D1&&#"
        let harness = CoordinatorHarness(installed: [safari, chrome], config: Config())
        let direct = try makeRequest(directString)
        let chosen = try makeRequest(chosenString)
        harness.router.decisions[direct.id] = .open(bundleID: safari.bundleID, reason: .rule(UUID()))

        harness.coordinator.handle(direct)
        harness.coordinator.handle(chosen)
        harness.picker.deliver(.chose(bundleID: chrome.bundleID))
        await harness.coordinator.settle()

        let urls = harness.opener.calls.map(\.url)
        #expect(urls.map(\.absoluteString) == [directString, chosenString])
        #expect(urls.map(\.dataRepresentation) == [Data(directString.utf8), Data(chosenString.utf8)])
        #expect(urls == [direct.url, chosen.url])
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func ownAppIsNeverOpenedEvenWhenRoutedOrChosen() async throws {
        let harness = CoordinatorHarness(installed: [ownApp, safari], config: Config())
        let request = try makeRequest("https://example.com/self")
        harness.router.decisions[request.id] = .open(bundleID: selfBundleID, reason: .defaultBrowser)

        harness.coordinator.handle(request)
        harness.picker.deliver(.chose(bundleID: selfBundleID))
        await harness.coordinator.settle()

        let unavailable = presentation(request, [safari], .targetUnavailable(bundleID: selfBundleID), pending: 1)
        let expected: [CoordinatorFakePicker.Event] = [.show(unavailable), .show(unavailable)]
        #expect(harness.picker.events == expected)
        #expect(harness.opener.calls.isEmpty)
        #expect(harness.coordinator.pendingCount == 1)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func choosingABrowserThatDisappearedRepresentsTheRequestFirst() async throws {
        let harness = CoordinatorHarness(
            installed: [safari, chrome],
            config: Config(shownBrowsers: [safari.bundleID, chrome.bundleID])
        )
        let first = try makeRequest("https://example.com/first")
        let second = try makeRequest("https://example.com/second")
        harness.coordinator.handle(first)
        harness.coordinator.handle(second)

        harness.catalog.installed = [safari]
        harness.picker.deliver(.chose(bundleID: chrome.bundleID))
        harness.picker.deliver(.cancel)
        await harness.coordinator.settle()

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(first, [safari, chrome], nil, pending: 1)),
            .updatePendingCount(2),
            .show(presentation(first, [safari], .targetUnavailable(bundleID: chrome.bundleID), pending: 2)),
            .show(presentation(second, [safari], nil, pending: 1))
        ]
        #expect(harness.picker.events == expected)
        #expect(harness.opener.calls.isEmpty)
        #expect(harness.picker.violations.isEmpty)
    }

    @Test func diagnosticsModeRoutesAndPresentsAsUsual() async throws {
        let harness = CoordinatorHarness(installed: [safari], config: Config(diagnostics: true))
        let known = try makeRequest("https://example.com/diagnostics")
        let unknown = LinkRequest(url: URL(filePath: "/Users/someone/page.html"), sourceBundleID: nil, alternativeRequested: true)
        harness.router.decisions[known.id] = .open(bundleID: safari.bundleID, reason: .alternative)

        harness.coordinator.handle(known)
        harness.coordinator.handle(unknown)
        await harness.coordinator.settle()

        let expected: [CoordinatorFakePicker.Event] = [
            .show(presentation(unknown, [safari], nil, pending: 1))
        ]
        #expect(harness.opener.calls == [CoordinatorFakeOpener.Call(url: known.url, bundleID: safari.bundleID)])
        #expect(harness.picker.events == expected)
        #expect(harness.configSource.reads == 2)
        #expect(harness.picker.violations.isEmpty)
    }

    private func makeRequest(_ string: String) throws -> LinkRequest {
        let url = try #require(URL(string: string))
        return LinkRequest(url: url, sourceBundleID: "com.tinyspeck.slackmacgap", alternativeRequested: false)
    }

    private func presentation(
        _ request: LinkRequest,
        _ choices: [BrowserApp],
        _ notice: PickerNotice?,
        pending: Int
    ) -> PickerPresentation {
        PickerPresentation(request: request, choices: choices, notice: notice, pendingCount: pending)
    }
}
