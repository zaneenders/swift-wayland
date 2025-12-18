import XXH3

func hash(_ string: String) -> UInt64 {
  XXH3.hash(string, seed: 42069)
}
