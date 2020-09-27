// Copyright © 2020 Roger Oba. All rights reserved.

import FeatureConfig
import JSEN
import LaunchDarkly

internal protocol LaunchDarklyClient {
    static func start(config: LDConfig, user: LDUser?, completion: (() -> Void)?)
    static var shared: Self? { get }
    func identify(user: LDUser, completion: (() -> Void)?)
    var allConfigs: [String:Any]? { get }
}

extension LaunchDarklyClient {
    /// - Precondition: must be called after starting the client.
    static func getCurrentConfigs(log: (String) -> Void) -> [String:Config] {
        guard let client = shared, let allConfigs = client.allConfigs else {
            log("getCurrentConfigs was invoked before starting '\(String(describing: self))'.")
            assertionFailure("Must call \(#function) only after starting the client.")
            return [:]
        }
        return allConfigs.compactMapValues { value in
            guard let jsen = JSEN(from: value) else { log("JSEN failed to be initialized from value: '\(value)'"); return nil }
            return Config(value: jsen)
        }
    }
}

// MARK: - LDClient conformance to LaunchDarklyClient

extension LDClient : LaunchDarklyClient {
    var allConfigs: [String : Any]? { allFlags }
    // swiftformat:disable redundantSelf
    static var shared: Self? { self.get() as! Self? }
    // swiftformat:enable redundantSelf
}
