public struct Padding: Equatable {
  public var top: UInt?
  public var right: UInt?
  public var bottom: UInt?
  public var left: UInt?

  public init() {}

  public init(all: UInt) {
    self.top = all
    self.right = all
    self.bottom = all
    self.left = all
  }

  public init(top: UInt? = nil, right: UInt? = nil, bottom: UInt? = nil, left: UInt? = nil) {
    self.top = top
    self.right = right
    self.bottom = bottom
    self.left = left
  }

  public init(horizontal: UInt, vertical: UInt) {
    self.top = vertical
    self.bottom = vertical
    self.left = horizontal
    self.right = horizontal
  }
}
