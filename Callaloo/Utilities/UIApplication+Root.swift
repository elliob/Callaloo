//
//  UIApplication+Root.swift
//  Callaloo
//

import UIKit

extension UIApplication {
    var callalooKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    func callalooRootViewController() -> UIViewController? {
        callalooKeyWindow?.rootViewController?.topMost
    }
}

private extension UIViewController {
    var topMost: UIViewController {
        if let presented = presentedViewController { return presented.topMost }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMost
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMost
        }
        return self
    }
}
