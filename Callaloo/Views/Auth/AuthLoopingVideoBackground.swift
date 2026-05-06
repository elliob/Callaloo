//
//  AuthLoopingVideoBackground.swift
//  Callaloo
//

import AVFoundation
import SwiftUI
import UIKit

/// Full-screen muted video that cycles through bundled clips in order, looping forever.
struct AuthLoopingVideoBackground: UIViewRepresentable {
    static let bundledClipNames = ["LoginBackground1", "LoginBackground2", "LoginBackground3"]

    func makeCoordinator() -> Coordinator {
        Coordinator(urls: Self.bundleVideoURLs())
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    static func bundleVideoURLs() -> [URL] {
        bundledClipNames.compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "mp4")
        }
    }

    final class Coordinator: NSObject {
        private let urls: [URL]
        private let player = AVPlayer()
        private var playerLayer: AVPlayerLayer?
        private var endObserver: NSObjectProtocol?
        private var index = 0

        init(urls: [URL]) {
            self.urls = urls
            super.init()
        }

        func attach(to container: PlayerContainerView) {
            guard !urls.isEmpty else { return }

            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            container.layer.insertSublayer(layer, at: 0)
            playerLayer = layer
            player.isMuted = true

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                guard let finished = notification.object as? AVPlayerItem,
                      finished == self.player.currentItem else { return }
                self.advance()
            }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )

            playCurrent()
            container.setNeedsLayout()
        }

        @objc private func appWillResignActive() {
            player.pause()
        }

        @objc private func appDidBecomeActive() {
            player.play()
        }

        func layout(in bounds: CGRect) {
            playerLayer?.frame = bounds
        }

        deinit {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            NotificationCenter.default.removeObserver(self)
            player.pause()
        }

        private func advance() {
            guard !urls.isEmpty else { return }
            index = (index + 1) % urls.count
            playCurrent()
        }

        private func playCurrent() {
            guard !urls.isEmpty else { return }
            let url = urls[index]
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            player.play()
        }
    }

    final class PlayerContainerView: UIView {
        weak var coordinator: Coordinator?

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            coordinator?.layout(in: bounds)
        }
    }
}
