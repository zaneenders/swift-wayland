import Foundation

struct Canvas: ~Copyable {
    let fd: FD
    private var buffer: UnsafeMutableRawPointer
    enum Buffer {
        case front
        case back
    }

    init(pixels: Int) {
        let (fd, pointer) = Self.createSharedFrameBuffer(pixels: pixels)
        self.fd = fd
        self.buffer = pointer!
    }

    func draw(_ side: Buffer, height: Int, width: Int) {
        let low: Int
        let high: Int
        switch side {
        case .front:
            low = 0
            high = height * width
        case .back:
            low = (height * width) + 1
            high = (height * width) * 2
        }
        let typedPixels = buffer.assumingMemoryBound(to: UInt32.self)
        for i in low..<high {
            if i.isMultiple(of: 5) {
                typedPixels[i] = 0xffffff
            } else {
                typedPixels[i] = 0x21b9ff
            }
        }
    }

    static func createSharedFrameBuffer(pixels: Int) -> (FD, UnsafeMutableRawPointer?) {
        let shared_name = UUID().uuidString
        let shared_fd = unsafe shm_open(shared_name, O_RDWR | O_EXCL | O_CREAT, 0600)
        unsafe shm_unlink(shared_name)
        let pointer = shared_fd.resizeBuffer(size: pixels, pointer: nil)
        return (shared_fd, pointer)
    }

    mutating func resize(pixels: Int) {
        self.buffer = fd.resizeBuffer(size: pixels * 2, pointer: self.buffer)!
    }

    deinit {
        buffer.deallocate()
        close(fd)
    }
}
