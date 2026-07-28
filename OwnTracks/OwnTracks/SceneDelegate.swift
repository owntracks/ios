//
//  SceneDelegate.swift
//  OwnTracks
//
//  Created by Christoph Krey on 28/07/2026.
//  Copyright © 2026 OwnTracks. All rights reserved.
//

import Foundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func sceneDidBecomeActive(_ scene: UIScene) {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.applicationDidBecomeActive(UIApplication.shared);
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.applicationWillResignActive(UIApplication.shared);
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
        ad.applicationDidEnterBackground(UIApplication.shared);
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for urlContext in URLContexts {
            let url = urlContext.url
            let ad = UIApplication.shared.delegate as! OwnTracksAppDelegate;
            ad.open(url);
        }
    }
}
