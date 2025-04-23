import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Ajuste do tamanho mínimo
    self.minSize = NSSize(width: 600, height: 800)

    // Registro dos plugins
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
