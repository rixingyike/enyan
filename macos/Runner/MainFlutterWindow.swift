import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    if let screen = self.screen ?? NSScreen.main {
        let screenFrame = screen.visibleFrame
        var newFrame = self.frame
        
        // Use standard tool/reader dimensions: 1000 x 800
        newFrame.size.width = 1000
        newFrame.size.height = 800
        
        // Center the window
        newFrame.origin.x = screenFrame.origin.x + (screenFrame.width - newFrame.size.width) / 2
        newFrame.origin.y = screenFrame.origin.y + (screenFrame.height - newFrame.size.height) / 2
        
        self.setFrame(newFrame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
