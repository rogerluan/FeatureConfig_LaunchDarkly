// Copyright © 2020 Roger Oba. All rights reserved.

import Combine
import FeatureConfig
import LaunchDarkly

public class LaunchDarklyProvider : Provider {
    /// Dictionary of keys and configs stored in-memory. Observe changes to this array using Combine.
    public var configsPublisher = CurrentValueSubject<[String:Config], Never>([:])
    public let logsPublisher = PassthroughSubject<Log, Never>()
    public var priority: Priority = .medium
    internal var clientProtocol: LaunchDarklyClient.Type { LDClient.self }

    public init(mobileKey: String) {
        var config = LDConfig(mobileKey: mobileKey)
        config.connectionTimeout = 20.0
        config.eventFlushInterval = 30.0
        config.streamingMode = .polling
        let anonymousUser = LDUser() // TODO: Evaluate starting with the current user already, if one is known. Do this when we have actual User models in place.
        clientProtocol.start(config: config, user: anonymousUser) { [weak self] in
            guard let self = self else { return }
            self.log(message: "'\(String(describing: self.clientProtocol))' started. The configs have been updated.", logLevel: .info)
            self.refresh()
        }
        log(message: "Loading cached configs into memory", logLevel: .info)
        refresh()
    }

    public func refresh() {
        log(message: "Refreshing configs", logLevel: .info)
        configsPublisher.value = clientProtocol.getCurrentConfigs(log: { [weak self] message in
            self?.log(message: message, logLevel: .warning)
        })
    }

    /// Changes the user on LaunchDarkly server asynchronously and, once done, it refreshes the configs loaded in memory.
    /// As always, the changes to the configs must be observed using Combine, hence why this method has no completion closure.
    ///
    /// - Precondition: must be called after starting the client.
    /// - Parameter userID: the user's unique identifier. Do not use PII for this field (such as email, phone, etc).
    public func configure(forUserID userID: String) {
        // TODO: Pull more info from the user to fill up these parameters? Do this when we have actual User models in place.
        let currentUser = LDUser(
            key: userID,
            name: nil,
            firstName: nil,
            lastName: nil,
            country: nil,
            email: nil,
            avatar: nil,
            custom: nil
        )
        log(message: "Changing user identity to:\n \(currentUser)", logLevel: .info)
        clientProtocol.shared!.identify(user: currentUser) { [weak self] in
            self?.log(message: "The identity was changed and the configs have been retrieved for the new user", logLevel: .info)
            self?.refresh()
        }
    }
}
