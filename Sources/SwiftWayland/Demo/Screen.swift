import Wayland

struct Screen: Block {
  let o: Orientation
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
  var layer: some Block {
    Group(o) {
      Word("Demo")
        .forground(.green)
        .background(.purple)
      for word in words {
        Word(word).scale(4)
          .forground(.white)
          .background(.random)
      }
    }
  }
}
