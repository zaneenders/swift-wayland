import Foundation
import Synchronization

struct Canvas: ~Copyable {
    let fd: FD
    let lock: Mutex<UnsafeMutableRawPointer>
    let size: Int

    init(bytes: Int) {
        let (fd, pointer) = Self.createSharedFrameBuffer(bytes: bytes)
        self.fd = fd
        self.lock = Mutex(pointer!)
        self.size = bytes
    }

    mutating func draw(_ count: UInt128, width: Int, height: Int, scale: Int) {
        print(#function, width, height)
        lock.withLock { buffer in
            let typedPixels = buffer.assumingMemoryBound(to: UInt32.self)
            for i in 0..<(width * height * scale) {
                typedPixels[i] = 0x00_FF_FF
            }
        }
    }

    static func createSharedFrameBuffer(bytes: Int) -> (FD, UnsafeMutableRawPointer?) {
        let shared_name = UUID().uuidString
        let shared_fd = unsafe shm_open(shared_name, O_RDWR | O_EXCL | O_CREAT, 0600)
        unsafe shm_unlink(shared_name)
        let pointer = shared_fd.resizeBuffer(size: bytes, pointer: nil)
        // NOTE: I wonder if I need to make my second buffer here?
        return (shared_fd, pointer)
    }

    deinit {
        lock.withLock { buffer in
            buffer.deallocate()
        }
        close(fd)
    }
}
