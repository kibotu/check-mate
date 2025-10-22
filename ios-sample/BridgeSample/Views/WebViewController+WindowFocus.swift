import UIKit

// MARK: - Window Focus Management
extension WebViewController {
    
    // MARK: - Internal State
    
    private static var hasFocusKey: UInt8 = 0
    private static var currentlyHasFocusKey: UInt8 = 0
    private static var hasRegisteredForFocusEventsKey: UInt8 = 0
    private static var focusCheckTimerKey: UInt8 = 0
    
    var hasFocus: Bool {
        get {
            return objc_getAssociatedObject(self, &Self.hasFocusKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &Self.hasFocusKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var currentlyHasFocus: Bool? {
        get {
            return objc_getAssociatedObject(self, &Self.currentlyHasFocusKey) as? Bool
        }
        set {
            objc_setAssociatedObject(self, &Self.currentlyHasFocusKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var hasRegisteredForFocusEvents: Bool {
        get {
            return objc_getAssociatedObject(self, &Self.hasRegisteredForFocusEventsKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &Self.hasRegisteredForFocusEventsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var focusCheckTimer: Timer? {
        get {
            return objc_getAssociatedObject(self, &Self.focusCheckTimerKey) as? Timer
        }
        set {
            objc_setAssociatedObject(self, &Self.focusCheckTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Public API
    
    /// Set to true in subclasses that want to receive focus change events
    @objc open var wantsToListenOnFocusEvents: Bool {
        get {
            return true // Default value
        }
    }
//    
//    /// Override this method to receive window focus change events
//    @objc open func onWindowFocusChanged(hasFocus: Bool) { }
    
    // MARK: - Lifecycle Methods
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleViewDidAppear()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        handleViewWillDisappear()
    }
    
    // MARK: - Internal Methods
    
    internal func setupFocusMonitoring() {
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    internal func handleViewDidAppear() {
        // Check actual focus state instead of assuming true
        // This prevents false positives when viewDidAppear is called but we're immediately navigating away
        let actualHasFocus = isViewControllerCurrentlyFocused()
        onWindowFocusChangedInternal(hasFocus: actualHasFocus)
        
        // Register for window focus events if subclass wants them and not already registered
        if wantsToListenOnFocusEvents {
            // Start/restart polling to detect when modals are presented over us
            startFocusMonitoring()
        }
    }
    
    internal func handleViewWillDisappear() {
        onWindowFocusChangedInternal(hasFocus: false)
        
        // Stop focus monitoring when view disappears
        if wantsToListenOnFocusEvents {
            stopFocusMonitoring()
        }
    }
    
    internal func cleanupFocusMonitoring() {
        focusCheckTimer?.invalidate()
        focusCheckTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private Implementation
    
    private func onWindowFocusChangedInternal(hasFocus: Bool) {
        if currentlyHasFocus != hasFocus {
            currentlyHasFocus = hasFocus
            // Orchard.i("[\(type(of: self))][onWindowFocusChanged] hasFocus: \(hasFocus)")
            onWindowFocusChanged(hasFocus: hasFocus)
        }
    }
    
    /// Called when app enters background
    @objc internal func appDidEnterBackground() {
        onWindowFocusChangedInternal(hasFocus: false)
    }
    
    /// Called when app enters foreground
    @objc internal func appWillEnterForeground() {
        // Check the actual focus state when app enters foreground
        // Don't assume it's true - let isViewControllerCurrentlyFocused() determine it
        // This avoids false positives when app state is still .inactive
        if isViewLoaded && view.window != nil {
            let hasFocus = isViewControllerCurrentlyFocused()
            onWindowFocusChangedInternal(hasFocus: hasFocus)
        }
    }
    
    /// Start monitoring for focus changes (modals, alerts, etc.)
    private func startFocusMonitoring() {
        guard wantsToListenOnFocusEvents else { return }
        
        // Check focus state every 16ms seconds
        focusCheckTimer?.invalidate()
        focusCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.checkFocusState()
        }
    }
    
    /// Stop monitoring for focus changes
    private func stopFocusMonitoring() {
        focusCheckTimer?.invalidate()
        focusCheckTimer = nil
    }
    
    /// Check if this view controller currently has focus
    private func checkFocusState() {
        let currentlyHasFocus = isViewControllerCurrentlyFocused()
        onWindowFocusChangedInternal(hasFocus: currentlyHasFocus)
    }
    
    /// Determine if this view controller is currently focused (not covered by modal/alert)
    private func isViewControllerCurrentlyFocused() -> Bool {
        // Check if app is in background or inactive
        if UIApplication.shared.applicationState != .active {
            return false
        }
        
        // Check if we're not in the view hierarchy
        guard view.window != nil, isViewLoaded else {
            return false
        }
        
        // Check if another window is key (overlay, alert, etc.)
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
           keyWindow != view.window {
            return false
        }
        
        // Check if we have a presented view controller covering us
        if presentedViewController != nil {
            return false
        }
        
        // Check if we're in a navigation controller and it has a presented view controller
        if let navController = navigationController,
           navController.presentedViewController != nil {
            return false
        }
        
        // Check if the tab bar controller (if any) has a presented view controller
        if let tabBarController = tabBarController,
           tabBarController.presentedViewController != nil {
            return false
        }
        
        return true
    }
}

