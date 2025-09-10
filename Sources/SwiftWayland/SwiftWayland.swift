import Wayland

#if Toolbar
import Foundation
#endif

struct Screen: Block {
    let words = [
        "apple", "banana", "orange", "grape", "strawberry",
        "blueberry", "raspberry", "watermelon", "pineapple", "kiwi",
        "mango", "peach", "plum", "cherry", "apricot", "nectarine",
        "date", "fig", "pomegranate", "cranberry", "gooseberry",
        "avocado", "coconut", "cashew", "almond", "walnut",
        "pecan", "hazelnut", "pistachio", "macadamia", "brazil nut",
        "chocolate", "coffee", "tea", "water", "milk", "juice",
        "bread", "rice", "pasta", "quinoa", "couscous",
        "chicken", "beef", "pork", "fish", "tofu", "beans",
        "salad", "soup", "pizza", "sandwich", "steak", "salmon",
        "eggs", "cheese", "yogurt", "nuts", "seeds", "oil", "vinegar", "salt", "pepper", "sugar",
    ]
    //    let words = ["Zane", "Was", "Here"]
    var layer: some Block {
        Group(.vertical) {
            for word in words {
                Word(word).scale(4)
            }
        }
    }
}

@main
@MainActor
struct SwiftWayland {
    static func main() async {
        let screen = Screen()
        #if Toolbar
        let formatter = DateFormatter()
        formatter.dateFormat = "yy-MM-dd HH:mm:ss"
        #else
        let state = AsyncState()
        #endif

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
                #if Toolbar
                let today = formatter.string(from: Date())
                let today_scale: Float = 2.0
                let today_space = Float(Wayland.glyphSpacing) * today_scale
                let today_textW = Float(Wayland.glyphW) * today_scale
                let today_total = (Float(today.count) * (today_textW + today_space))
                let text_y = Float(
                    (Double(Wayland.toolbar_height) / 2.0) - ((Double(Wayland.glyphH) * Double(today_scale)) / 2.0))
                let clock = (
                    text: Text(
                        today, at: (Float(winW) - today_total, text_y), scale: today_scale,
                        color: Color.black),
                    rect: Rect(
                        dst_p0: (Float(winW) - today_total, 0),
                        dst_p1: (Float(winW), Float(winH)),
                        color: Color.teal
                    )
                )
                texts.append(clock.text)
                rects.append(clock.rect)
                #else
                let snapShot = await state.view()
                let asciiStart = 32
                let asciiEnd = 126
                let code = asciiStart + (snapShot.tick % (asciiEnd - asciiStart + 1))
                let cmsg = UnicodeScalar(code).map { String(Character($0)) } ?? " "
                let words = ["Scribe", cmsg, "\(snapShot.count)"]

                let space = Wayland.glyphSpacing * Wayland.scale
                let textH = Wayland.glyphH * Wayland.scale
                let total = (UInt(words.count) * (textH + space)) - space
                let startY = (UInt(winH) - total) / 2
                for (i, word) in words.enumerated() {
                    let textW =
                        UInt(word.count) * (UInt(Wayland.glyphW + Wayland.glyphSpacing) * Wayland.scale) - space
                    let penX = (winW - textW) / 2
                    let penY = startY + (UInt(i) * (textH + space))
                    let text = Text(word, at: (penX, penY), scale: Wayland.scale)
                    texts.append(text)
                }
                rects.append(
                    Rect(
                        dst_p0: (0, 0),
                        dst_p1: (winW, 200),
                        color: Color.teal
                    ))
                rects.append(
                    Rect(
                        dst_p0: (winW, winH - 200),
                        dst_p1: (0, winH),
                        color: Color.green
                    ))
                #endif
                Wayland.drawFrame((height: winH, width: winW), screen)
                //Wayland.drawFrame((height: winH, width: winW), texts, rects)
                texts = []
                rects = []
            #if !Toolbar
            case .key(let code, let keyState):
                if code == 1 {
                    Wayland.exit()
                }
                if keyState == 1 {
                    await state.bump()
                }
            #endif
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
}

#if !Toolbar
struct SnapShot {
    let tick: Int
    let count: Int
}

actor AsyncState {
    var tick = 0
    var count = 0

    init() {
        Task {
            await start()
        }
    }

    func start() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                self.tick += 1
            }
        }
    }

    func bump() {
        count += 1
    }

    func view() -> SnapShot {
        SnapShot(tick: tick, count: count)
    }
}
#endif
