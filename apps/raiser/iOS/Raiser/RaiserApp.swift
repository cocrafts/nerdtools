import SwiftUI

func handleAppDidFinishLaunching() {
	print("App did launch..")
}

#if os(macOS)
	final class AppDelegate: NSObject, NSApplicationDelegate {
		func applicationDidFinishLaunching(_: Notification) {
			if let window = NSApplication.shared.windows.first {
				window.titleVisibility = .hidden
				window.titlebarAppearsTransparent = true
				window.isOpaque = false
				window.backgroundColor = NSColor.clear
			}

			handleAppDidFinishLaunching()
		}
	}
#else
	import UIKit

	final class AppDelegate: NSObject, UIApplicationDelegate {
		func application(
			_: UIApplication,
			didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
		) -> Bool {
			handleAppDidFinishLaunching()
			return true
		}
	}
#endif

@main
struct RaiserApp: App {
	#if os(macOS)
		@NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
	#else
		@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	#endif

	var body: some Scene {
		WindowGroup {
			ContentView(core: Core())
		}
	}
}
