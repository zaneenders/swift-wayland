import XXH3

typealias Hash = UInt64

func hash(_ string: String) -> Hash {
  XXH3.hash(string, seed: 42069)
}
