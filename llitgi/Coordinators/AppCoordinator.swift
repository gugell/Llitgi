//
//  AppCoordinator.swift
//  llitgi
//
//  Created by Xavi Moll on 31/07/2018.
//  Copyright © 2018 xmollv. All rights reserved.
//

import Foundation
import UIKit
import SafariServices

protocol Coordinator {
    func start()
}

final class AppCoordinator: NSObject, Coordinator {
    
    //MARK: Private properties
    private let factory: ViewControllerFactory
    private let userManager: UserManager
    private let dataProvider: DataProvider
    private let splitViewController: UISplitViewController
    private let tabBarController: UITabBarController
    private let theme: Theme
    private let badgeManager: BadgeManager
    weak private var presentedSafari: SFSafariViewController?
    
    private lazy var presentSafariClosure: ((SFSafariViewController) -> Void)? = { [weak self] sfs in
        guard let strongSelf = self else { return }
        strongSelf.presentedSafari = sfs
        strongSelf.presentedSafari?.delegate = strongSelf
        strongSelf.splitViewController.showDetailViewController(sfs, sender: nil)
    }
    
    //MARK: Lifecycle
    init(window: UIWindow, factory: ViewControllerFactory, userManager: UserManager, dataProvider: DataProvider, theme: Theme) {
        self.factory = factory
        self.userManager = userManager
        self.dataProvider = dataProvider
        self.theme = theme
        self.splitViewController = SplitViewController()
        self.tabBarController = TabBarController()
        self.badgeManager = BadgeManager(notifier: dataProvider.badgeNotifier, userManager: userManager)

        super.init()
        
        let tabs = self.factory.listsViewControllers.map { (vc) -> UINavigationController in
            vc.safariToPresent = self.presentSafariClosure
            vc.settingsButtonTapped = { [weak self] in self?.showSettings() }
            vc.selectedTag = { [weak self] tag in self?.show(tag: tag) }
            vc.tagsModification = { [weak self] item in self?.showTagsPicker(for: item) }
            let navController = NavigationController(rootViewController: vc)
            navController.navigationBar.prefersLargeTitles = true
            navController.navigationBar.barStyle = self.theme.barStyle
            return navController
        }

        self.tabBarController.tabBar.barStyle = self.theme.barStyle
        self.tabBarController.delegate = self
        self.tabBarController.setViewControllers(tabs, animated: false)
        self.addTagTabIfNeeded()
        
        self.splitViewController.viewControllers = [self.tabBarController]
        self.splitViewController.preferredDisplayMode = .allVisible
        self.splitViewController.delegate = self
        self.splitViewController.view.backgroundColor = self.theme.backgroundColor
        
        // Configure the window
        window.makeKeyAndVisible()
        window.tintColor = self.theme.tintColor
        window.rootViewController = self.splitViewController
    }
    
    //MARK: Public methods
    func start() {
        if !self.userManager.isLoggedIn {
            self.showLogin(animated: false)
        }
    }
    
    //MARK: Private methods
    private func showLogin(animated: Bool = true) {
        let login = self.factory.loginViewController
        login.modalPresentationStyle = .formSheet
        
        login.safariToPresent = { [weak login] sfs in
            login?.present(sfs, animated: true, completion: nil)
        }
        
        login.loginFinished = { [weak self] in
            self?.splitViewController.dismiss(animated: true, completion: { [weak self] in
                self?.showFullSync()
            })
        }
        
        self.splitViewController.present(login, animated: animated, completion: nil)
    }
    
    private func showSettings() {
        let settingsViewController = self.factory.settingsViewController
        
        settingsViewController.doneBlock = { [weak self] in
            self?.splitViewController.dismiss(animated: true, completion: nil)
        }
        
        settingsViewController.logoutBlock = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.presentedSafari = nil
            if strongSelf.splitViewController.traitCollection.horizontalSizeClass == .regular {
                strongSelf.splitViewController.viewControllers = [strongSelf.tabBarController]
            }
            
            strongSelf.splitViewController.dismiss(animated: true, completion: { [weak self] in
                self?.showLogin()
                self?.removeTagTab()
                self?.dataProvider.clearLocalStorage()
            })
        }
        let navController = NavigationController(rootViewController: settingsViewController)
        navController.modalPresentationStyle = .formSheet
        self.splitViewController.present(navController, animated: true, completion: nil)
    }
    
    private func show(tag: Tag) {
        let tagViewController = self.factory.itemsViewController(for: tag)
        tagViewController.selectedTag = { [weak self] tag in self?.show(tag: tag) }
        tagViewController.safariToPresent = self.presentSafariClosure
        tagViewController.tagsModification = { [weak self] item in self?.showTagsPicker(for: item) }
        #warning("This hack will bit back")
        ((self.splitViewController.viewControllers.first as? UITabBarController)?.selectedViewController as? UINavigationController)?.pushViewController(tagViewController, animated: true)
    }
    
    private func showTagsPicker(for item: Item) {
        let tagPicker = self.factory.manageTagsViewController(for: item) { [weak self] in
            self?.splitViewController.dismiss(animated: true, completion: nil)
        }
        let navController = NavigationController(rootViewController: tagPicker)
        navController.modalPresentationStyle = .formSheet
        self.splitViewController.present(navController, animated: true, completion: nil)
    }
    
    private func showFullSync() {
        let fullSync = self.factory.fullSyncViewController
        fullSync.finishedSyncing = { [weak self] in
            self?.addTagTabIfNeeded()
            self?.splitViewController.dismiss(animated: true, completion: nil)
        }
        fullSync.modalPresentationStyle = .overFullScreen
        fullSync.modalTransitionStyle = .crossDissolve
        self.splitViewController.present(fullSync, animated: true, completion: nil)
    }
    
    private func addTagTabIfNeeded() {
        guard !dataProvider.tags.isEmpty, var currentTabs = self.tabBarController.viewControllers, currentTabs.count == 3 else { return }
        let tags = self.factory.tagsViewController
        tags.settingsButtonTapped = { [weak self] in self?.showSettings() }
        tags.selectedTag = { [weak self] tag in self?.show(tag: tag) }
        let tagsNavController = NavigationController(rootViewController: tags)
        tagsNavController.navigationBar.prefersLargeTitles = true
        tagsNavController.navigationBar.barStyle = self.theme.barStyle
        currentTabs.append(tagsNavController)
        self.tabBarController.setViewControllers(currentTabs, animated: false)
    }
    
    private func removeTagTab() {
        guard let currentTabs = self.tabBarController.viewControllers, currentTabs.count == 4 else { return }
        self.tabBarController.setViewControllers(Array(currentTabs.dropLast()), animated: false)
    }
}

extension AppCoordinator: UISplitViewControllerDelegate {
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        if splitViewController.presentedViewController is SFSafariViewController {
            splitViewController.dismiss(animated: false, completion: nil)
        }
        return self.presentedSafari
    }
}

extension AppCoordinator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let newViewController = (viewController as? UINavigationController)?.topViewController else { return true }
        guard let currentViewController = (tabBarController.selectedViewController as? UINavigationController)?.topViewController else { return true }

        if let list = newViewController as? ItemsViewController {
            guard list.isEqual(currentViewController) else { return true }
            list.scrollToTop()
        }
        return true
    }
}

extension AppCoordinator: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        guard self.splitViewController.traitCollection.horizontalSizeClass == .regular else { return }
        self.presentedSafari = nil
        self.splitViewController.viewControllers = [self.tabBarController]
    }
}
