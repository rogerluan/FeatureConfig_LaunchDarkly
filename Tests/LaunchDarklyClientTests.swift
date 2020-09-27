// Copyright © 2020 Roger Oba. All rights reserved.

@testable import FeatureConfig_LaunchDarkly
import CwlPreconditionTesting
import FeatureConfig
import LaunchDarkly
import XCTest

final class LaunchDarklyClientTests : XCTestCase {
    final class MockClient : LaunchDarklyClient {
        static var shared: MockClient?
        var allConfigs: [String:Any]?

        static func start(config: LDConfig, user: LDUser?, completion: (() -> Void)?) {
            shared = MockClient()
            completion?()
        }

        func identify(user: LDUser, completion: (() -> Void)?) { }
    }

    func test_getCurrentConfigs_whenClientDidntStart_shouldAssertAndLog() {
        MockClient.shared = nil
        let logExpectation = expectation(description: name)
        let exception = CwlPreconditionTesting.catchBadInstruction {
            // Since the command above throws an assertionFailure, it never results in anything, thus we can't check its return value
            _ = MockClient.getCurrentConfigs { _ in
                logExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
        XCTAssertNotNil(exception) // Verify that it actually threw an exception
    }

    func test_getCurrentConfigs_withValidConfigs_shouldReturnConfigs() {
        let expectation = self.expectation(description: name)
        MockClient.start(config: LDConfig(mobileKey: ""), user: nil) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
        MockClient.shared!.allConfigs = [
            "my_int" : 42,
            "my_string" : "some_value",
        ]
        let parsedConfigs = MockClient.getCurrentConfigs(log: { _ in })
        XCTAssertEqual(parsedConfigs, [
            "my_int" : Config(value: .int(42)),
            "my_string" : Config(value: .string("some_value")),
        ])
    }
}
