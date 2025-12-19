import XXH3

typealias Hash = UInt64

func hash(_ string: String) -> Hash {
  XXH3.hash(string, seed: 42069)
}

func hash(_ value: UInt64) -> Hash {
  XXH3.hash(value, seed: 42069)
}
