import Foundation

typealias FD = Int32

// MARK: Shared
extension FD {
    internal func resizeBuffer(size: Int) -> UnsafeMutableRawPointer? {
        ftruncate(self, size)
        let pointer = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, self, 0)
        return pointer
    }
}
