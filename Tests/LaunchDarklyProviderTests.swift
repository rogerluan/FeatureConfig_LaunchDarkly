// Copyright © 2020 Roger Oba. All rights reserved.

@testable import FeatureConfig_LaunchDarkly
import Combine
import FeatureConfig
import LaunchDarkly
import XCTest

final class LaunchDarklyProviderTests: XCTestCase {
    private var sut: LaunchDarklyProvider!
    private var cancellables: Set<AnyCancellable>!

    final class MockLaunchDarklyProvider : LaunchDarklyProvider {
        override var clientProtocol: LaunchDarklyClient.Type { MockClient.self }
    }

    final class MockClient : LaunchDarklyClient {
        var didChangeUser: Bool = false
        var allConfigs: [String:Any]? = [:]

        static func start(config: LDConfig, user: LDUser?, completion: (() -> Void)?) {
            shared = MockClient()
            completion?()
        }

        static var shared: MockClient?

        func identify(user: LDUser, completion: (() -> Void)?) {
            didChangeUser = true
            completion?()
        }
    }

    override func setUp() {
        super.setUp()
        sut = MockLaunchDarklyProvider(mobileKey: "test")
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        super.tearDown()
    }

    func test_initialization_withDefaultClientProtocol_shouldNotHaveNilClientSharedInstance() {
        let provider = LaunchDarklyProvider(mobileKey: "test")
        XCTAssertNotNil(provider.clientProtocol.shared)
    }

    func test_priority_shouldNotBeMinimumNorMaximum() {
        XCTAssertGreaterThan(sut.priority, .lowest)
        XCTAssertLessThan(sut.priority, .highest)
    }

    func test_refresh_withValidConfigs_shouldTriggerConfigsObservables() {
        let expectation = self.expectation(description: name)
        sut.configsPublisher
            .assertOutput(expectedValues: [
                [:],
                [ "testing_key" : Config(value: .string("my_value")) ],
            ], expectation: expectation)
            .store(in: &cancellables)
        MockClient.shared?.allConfigs?["testing_key"] = "my_value"
        sut.refresh()
        waitForExpectations(timeout: 1)
    }

    func test_refresh_withInvalidConfigs_shouldLogWarning() {
        let expectation = self.expectation(description: name)
        sut.logsPublisher
            .assertOutput(expectedValues: [
                ("Refreshing configs", .info, nil, nil, #file, #function, #line),
                ("JSEN failed to be initialized", .warning, nil, nil, #file, #function, #line),
            ], by: {
                let receivedMessage = $0.0
                let expectedMessagePrefix = $1.0
                return receivedMessage.starts(with: expectedMessagePrefix)
            }, expectation: expectation)
            .store(in: &cancellables)
        MockClient.shared?.allConfigs?["testing_key"] = NSObject() // Just a weird object
        sut.refresh()
        waitForExpectations(timeout: 1)
    }

    func test_configure_shouldLogAndRefresh() {
        let logExpectation = expectation(description: name + "log")
        let refreshExpectation = expectation(description: name + "refresh")
        sut.logsPublisher
            .assertOutput(expectedValues: [
                ("Changing user identity", .info, nil, nil, #file, #function, #line),
                ("The identity was changed", .info, nil, nil, #file, #function, #line),
                ("Refreshing configs", .info, nil, nil, #file, #function, #line),
            ], by: {
                let receivedMessage = $0.0
                let expectedMessagePrefix = $1.0
                return receivedMessage.starts(with: expectedMessagePrefix)
            }, expectation: logExpectation)
            .store(in: &cancellables)
        sut.configsPublisher
            .assertOutput(expectedValues: [
                [:],
                [ "testing_key" : Config(value: .string("my_value")) ],
            ], expectation: refreshExpectation)
            .store(in: &cancellables)
        MockClient.shared?.allConfigs?["testing_key"] = "my_value"
        sut.configure(forUserID: "fake_id")
        XCTAssertTrue((sut.clientProtocol.shared as! MockClient).didChangeUser)
        waitForExpectations(timeout: 1)
    }
}

// MARK: - Convenience
// Consider moving these to a standalone Combine + XCTest utility package

extension Publisher where Output : Equatable {
    func assertOutput(expectedValues: [Output], expectation: XCTestExpectation) -> AnyCancellable {
        return assertOutput(expectedValues: expectedValues, by: ==, expectation: expectation)
    }
}

extension Publisher {
    func assertOutput(expectedValues: [Output], by areEquivalent: @escaping (Output, Output) -> Bool, expectation: XCTestExpectation) -> AnyCancellable {
        var expectedValues = expectedValues
        return sink(receiveCompletion: { _ in
            // We don't need to handle completion.
        }, receiveValue: { value in
            guard let expectedValue = expectedValues.first else { XCTFail("The publisher emitted more values than expected."); return }
            guard areEquivalent(value, expectedValue) else { XCTFail("Expected received value '\(value)' to match first expected value '\(expectedValue)'"); return }
            expectedValues.removeFirst()
            if expectedValues.isEmpty {
                expectation.fulfill()
            }
        })
    }
}
