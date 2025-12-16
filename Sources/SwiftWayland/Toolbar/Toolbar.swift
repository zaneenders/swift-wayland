import Foundation
import Wayland

#if Toolbar
@MainActor
func runToolbar() async {
    let formatter = DateFormatter()
    formatter.dateFormat = "yy-MM-dd HH:mm:ss"

    Wayland.setup()
    var texts: [Text] = []
    var rects: [Rect] = []
    event_loop: for await ev in Wayland.events() {
        switch ev {
        case .frame(let winH, let winW):
            /*
            This is a mess well I figure out a more declaritive way of writing this code.
            It may be usefull to expose the current window height and wdith but I want layout
            logic to be more declaritive.
            */
            let today = formatter.string(from: Date())
            let today_scale: UInt = 2
            let today_space = Wayland.glyphSpacing * today_scale
            let today_textW = Wayland.glyphW * today_scale
            let today_total = (UInt(today.count) * (today_textW + today_space))
            let text_y =
                (Wayland.toolbar_height / 2) - ((Wayland.glyphH * today_scale) / 2)
            let clock = (
                text: Text(
                    today, at: (winW - today_total, text_y), scale: today_scale,
                    color: Color.black),
                rect: Rect(
                    dst_p0: (winW - today_total, 0),
                    dst_p1: (winW, winH),
                    color: Color.teal
                )
            )
            texts.append(clock.text)
            rects.append(clock.rect)
            Wayland.drawFrame((height: UInt32(winH), width: UInt32(winW)), texts, rects)
            texts = []
            rects = []
        }
    }

    // Read the final state
    switch Wayland.state {
    case .error(let reason):
        print("error: \(reason)")
    case .running, .exit:
        ()
    }
}
#endif
