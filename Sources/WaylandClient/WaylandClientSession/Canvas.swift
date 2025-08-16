import Foundation
import Synchronization

struct Canvas: ~Copyable {
    let fd: FD
    let lock: Mutex<UnsafeMutableRawPointer>

    init(bytes: Int) {
        let (fd, pointer) = Self.createSharedFrameBuffer(bytes: bytes)
        self.fd = fd
        self.lock = Mutex(pointer!)
    }

    mutating func draw(_ count: UInt128, height: Int, width: Int) {
        let squareSize = 50
        let squareSpeed = 25

        let xPos = Int((count * UInt128(squareSpeed)) % UInt128(width - squareSize))
        let yPos = (height - squareSize) / 2

        lock.withLock { buffer in
            let typedPixels = buffer.assumingMemoryBound(to: UInt32.self)

            // we should clear the screen height and width here
            for i in 0..<height * width {
                typedPixels[i] = 0x000000
            }

            for y in yPos..<yPos + squareSize {
                for x in xPos..<xPos + squareSize {
                    if x >= 0 && x < width && y >= 0 && y < height {
                        let index = y * width + x
                        typedPixels[index] = 0x21b9ff
                    }
                }
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
