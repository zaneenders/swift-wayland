import Foundation
import Synchronization

typealias FD = Int32

enum Side {
    case front
    case back
}

struct Canvas: ~Copyable {
    let fd: FD
    private let fp: UnsafeMutablePointer<UInt32>
    private let bp: UnsafeMutablePointer<UInt32>
    let half: Int
    let size: Int
    let scale: Int

    init(bytes: Int, scale: Int) {
        self.scale = scale
        let (fd, fp, half, bp) = Self.createSharedFrameBuffer(bytes: bytes)
        self.fd = fd
        self.half = half
        self.fp = fp.bindMemory(to: UInt32.self, capacity: half / 4)
        self.bp = bp.bindMemory(to: UInt32.self, capacity: half / 4)
        self.size = bytes
    }

    mutating func draw(_ side: Side, width: Int, height: Int) {
        let buffer: UnsafeMutablePointer<UInt32>
        switch side {
        case .front:
            buffer = fp
        case .back:
            buffer = bp
        }

        for x in 0..<width * scale {
            for y in 0..<height * scale {
                let i = (y * width * scale) + x
                buffer[i] = 0xFF_00_FF_FF
            }
        }
    }

    static func createSharedFrameBuffer(bytes: Int) -> (FD, UnsafeMutableRawPointer, Int, UnsafeMutableRawPointer) {
        let shared_name = UUID().uuidString
        let shared_fd = unsafe shm_open(shared_name, O_RDWR | O_EXCL | O_CREAT, 0600)
        unsafe shm_unlink(shared_name)
        ftruncate(shared_fd, bytes)
        let half = (bytes / 2)
        let front_ptr = mmap(nil, half, PROT_READ | PROT_WRITE, MAP_SHARED, shared_fd, 0)!
        let back_ptr = mmap(nil, half, PROT_READ | PROT_WRITE, MAP_SHARED, shared_fd, half)!
        return (shared_fd, front_ptr, half, back_ptr)
    }

    deinit {
        munmap(fp, half / 4)
        munmap(bp, half / 4)
        close(fd)
    }
}
