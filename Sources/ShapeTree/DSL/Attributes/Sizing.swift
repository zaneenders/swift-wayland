public enum Sizing: Equatable {
  case fixed(UInt)  // Specify a specify size
  case fit  // Fit to the size needed
  case grow  // Grow to the space allowed
}
