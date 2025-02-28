import AppKit
import SwiftUI

struct KeyButton: View {
  @Binding var text: String
  let placeholder: String
  @State private var isListening = false
  @State private var oldValue = ""
  var validationError: ValidationErrorType? = nil
  @EnvironmentObject var userConfig: UserConfig

  var body: some View {
    Button(action: {
      oldValue = text  // Store the old value when entering listening mode
      isListening = true
      // We no longer need to notify UserConfig that we're starting to edit a key
    }) {
      Text(text.isEmpty ? placeholder : text)
        .frame(width: 32, height: 24)
        .background(
          RoundedRectangle(cornerRadius: 5)
            .fill(backgroundColor)
            .overlay(
              RoundedRectangle(cornerRadius: 5)
                .stroke(borderColor, lineWidth: 1)
            )
        )
        .foregroundColor(text.isEmpty ? .gray : .primary)
    }
    .buttonStyle(PlainButtonStyle())
    .background(
      KeyListenerView(
        isListening: $isListening, text: $text, oldValue: $oldValue, userConfig: userConfig))
  }

  private var backgroundColor: Color {
    if isListening {
      return Color.blue.opacity(0.2)
    } else if validationError != nil {
      return Color.red.opacity(0.1)
    } else {
      return Color(.controlBackgroundColor)
    }
  }

  private var borderColor: Color {
    if isListening {
      return Color.blue
    } else if validationError != nil {
      return Color.red
    } else {
      return Color.gray.opacity(0.5)
    }
  }
}

// NSViewRepresentable to listen for key events
struct KeyListenerView: NSViewRepresentable {
  @Binding var isListening: Bool
  @Binding var text: String
  @Binding var oldValue: String
  var userConfig: UserConfig

  func makeNSView(context: Context) -> NSView {
    let view = KeyListenerNSView()
    view.isListening = $isListening
    view.text = $text
    view.oldValue = $oldValue
    view.userConfig = userConfig
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let view = nsView as? KeyListenerNSView {
      view.isListening = $isListening
      view.text = $text
      view.oldValue = $oldValue
      view.userConfig = userConfig

      // When isListening changes to true, make this view the first responder
      if isListening {
        DispatchQueue.main.async {
          view.window?.makeFirstResponder(view)
        }
      }
    }
  }

  class KeyListenerNSView: NSView {
    var isListening: Binding<Bool>?
    var text: Binding<String>?
    var oldValue: Binding<String>?
    var userConfig: UserConfig?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      // Don't automatically become first responder here
      // We'll do it in updateNSView when isListening becomes true
    }

    override func keyDown(with event: NSEvent) {
      guard let isListening = isListening, let text = text, isListening.wrappedValue else {
        super.keyDown(with: event)
        return
      }

      // Handle escape key - cancel and revert to old value
      if event.keyCode == 53 {  // Escape key
        if let oldValue = oldValue {
          text.wrappedValue = oldValue.wrappedValue
        }
        DispatchQueue.main.async {
          isListening.wrappedValue = false
          // Notify UserConfig that we've finished editing a key
          self.userConfig?.finishEditingKey()
        }
        return
      }

      // Handle backspace/delete - clear the value
      if event.keyCode == 51 || event.keyCode == 117 {  // Backspace or Delete
        text.wrappedValue = ""
        DispatchQueue.main.async {
          isListening.wrappedValue = false
          // Notify UserConfig that we've finished editing a key
          self.userConfig?.finishEditingKey()
        }
        return
      }

      // Handle regular key presses
      if let characters = event.characters, !characters.isEmpty {
        text.wrappedValue = String(characters.first!)
        // Set isListening to false after a short delay to ensure the key event is processed
        DispatchQueue.main.async {
          isListening.wrappedValue = false
          // Notify UserConfig that we've finished editing a key
          self.userConfig?.finishEditingKey()
        }
      }
    }

    // Add this method to handle when the view loses focus
    override func resignFirstResponder() -> Bool {
      // If we're still in listening mode when losing focus, exit listening mode
      if let isListening = isListening, isListening.wrappedValue {
        DispatchQueue.main.async {
          isListening.wrappedValue = false
          // Notify UserConfig that we've finished editing a key
          self.userConfig?.finishEditingKey()
        }
      }
      return super.resignFirstResponder()
    }
  }
}

#Preview {
  struct Container: View {
    @State var text = "a"
    @StateObject var userConfig = UserConfig()

    var body: some View {
      VStack(spacing: 20) {
        KeyButton(text: $text, placeholder: "Key")
        KeyButton(text: $text, placeholder: "Key", validationError: .duplicateKey)
        KeyButton(text: $text, placeholder: "Key", validationError: .emptyKey)
        KeyButton(text: $text, placeholder: "Key", validationError: .nonSingleCharacterKey)
        Text("Current value: '\(text)'")
      }
      .padding()
      .frame(width: 300)
      .environmentObject(userConfig)
    }
  }

  return Container()
}
