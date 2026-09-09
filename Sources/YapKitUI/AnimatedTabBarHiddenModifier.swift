//
//  AnimatedTabBarHiddenModifier.swift
//  YapKitSDK
//
//  Created by Nick Rogers on 9/3/26.
//


import SwiftUI
#if canImport(UIKit)
import UIKit

public struct AnimatedTabBarHiddenModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(TabBarTransitionRepresentable())
    }
}

private struct TabBarTransitionRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> TabBarTransitionViewController {
        TabBarTransitionViewController()
    }

    func updateUIViewController(_ uiViewController: TabBarTransitionViewController, context: Context) {}
}

private final class TabBarTransitionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
        view.isUserInteractionEnabled = false
    }

    private var actualTransitionCoordinator: UIViewControllerTransitionCoordinator? {
        if let c = self.transitionCoordinator { return c }
        var current: UIViewController? = self.parent
        while let c = current {
            if let tc = c.transitionCoordinator { return tc }
            current = c.parent
        }
        return nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let tabBar = findTabBar() else { return }

        let height = tabBar.frame.height > 0 ? tabBar.frame.height : 83
        let targetTransform = CGAffineTransform(translationX: 0, y: height + 30)

        // A transform only moves the tab bar visually; UIKit still includes
        // its original frame in the safe area. Hide it for layout as well so
        // a SwiftUI safeAreaInset (such as the chat composer) can use the
        // space it occupied. The system safe area for the home indicator is
        // retained by UIKit.
        tabBar.isHidden = true
        tabBar.transform = targetTransform
        tabBar.alpha = 0.0

        if animated, let coordinator = actualTransitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                // Keep the hidden state in sync with the layout while the
                // transition coordinator handles the surrounding transition.
            }, completion: { context in
                if context.isCancelled {
                    tabBar.transform = .identity
                    tabBar.alpha = 1.0
                    tabBar.isHidden = false
                }
            })
        } else {
            // The tab bar is already hidden above; dispatching an animation
            // here would leave its safe-area contribution in place until the
            // animation finished.
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let tabBar = findTabBar() else { return }

        tabBar.isHidden = false

        if animated, let coordinator = actualTransitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                tabBar.transform = .identity
                tabBar.alpha = 1.0
            }, completion: { context in
                if context.isCancelled {
                    let height = tabBar.frame.height > 0 ? tabBar.frame.height : 83
                    tabBar.transform = CGAffineTransform(translationX: 0, y: height + 30)
                    tabBar.alpha = 0.0
                }
            })
        } else {
            DispatchQueue.main.async {
                tabBar.transform = CGAffineTransform(
                    translationX: 0,
                    y: tabBar.frame.height + 30
                )
                tabBar.alpha = 0.0
                UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
                    tabBar.transform = .identity
                    tabBar.alpha = 1.0
                }
            }
        }
    }

    private func findTabBar() -> UITabBar? {
        if let tbc = self.tabBarController {
            return tbc.tabBar
        }
        var current: UIViewController? = self
        while let c = current {
            if let tbc = c as? UITabBarController {
                return tbc.tabBar
            }
            if let tbc = c.tabBarController {
                return tbc.tabBar
            }
            current = c.parent
        }
        if let window = view.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return findTabBar(in: window)
        }
        return nil
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar {
            return tabBar
        }
        for subview in view.subviews {
            if let tabBar = findTabBar(in: subview) {
                return tabBar
            }
        }
        return nil
    }
}

public extension View {
    func animatedTabBarHidden() -> some View {
        modifier(AnimatedTabBarHiddenModifier())
    }
}
#endif
