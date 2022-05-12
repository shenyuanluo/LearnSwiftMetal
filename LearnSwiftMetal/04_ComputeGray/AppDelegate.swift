//
//  AppDelegate.swift
//  04_ComputeGray
//
//  Created by ShenYuanLuo on 2022/5/12.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window                     = UIWindow.init(frame: UIScreen.main.bounds)
        self.window?.backgroundColor    = .white
        self.window?.rootViewController = ViewController()
        self.window?.makeKeyAndVisible()
        return true
    }


}

