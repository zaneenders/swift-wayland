import Foundation
import Synchronization

typealias FD = Int32

struct Canvas: ~Copyable {
    let fd: FD
    private let fp: UnsafeMutablePointer<UInt32>
    private let bp: UnsafeMutablePointer<UInt32>
    let half: Int
    let size: Int

    init(bytes: Int) {
        let (fd, fp, half, bp) = Self.createSharedFrameBuffer(bytes: bytes)
        self.fd = fd
        self.half = half
        self.fp = fp.bindMemory(to: UInt32.self, capacity: half)
        self.bp = bp.bindMemory(to: UInt32.self, capacity: half)
        self.size = bytes
    }

    enum Side {
        case front
        case back
    }

    mutating func draw(_ side: Side, _ color: UInt32, width: Int, height: Int, scale: Int) {
        let frame_byte_count = width * height * scale
        print(#function, size, side, width, height, scale, frame_byte_count, frame_byte_count * 2, size, size / 2)
        switch side {
        case .front:
            for i in 0..<frame_byte_count {
                fp[i] = color
            }
        case .back:
            for i in 0..<frame_byte_count {
                bp[i] = color
            }
        }
    }

    static func createSharedFrameBuffer(bytes: Int) -> (FD, UnsafeMutableRawPointer, Int, UnsafeMutableRawPointer) {
        let shared_name = UUID().uuidString
        let shared_fd = unsafe shm_open(shared_name, O_RDWR | O_EXCL | O_CREAT, 0600)
        unsafe shm_unlink(shared_name)
        ftruncate(shared_fd, bytes)
        let half = (bytes / 2)
        assert(half + half == bytes)
        print(#function, half)
        let front_ptr = mmap(nil, half, PROT_READ | PROT_WRITE, MAP_SHARED, shared_fd, 0)!
        let back_ptr = mmap(nil, half, PROT_READ | PROT_WRITE, MAP_SHARED, shared_fd, half)!
        return (shared_fd, front_ptr, half, back_ptr)
    }

    deinit {
        fp.deallocate()
        bp.deallocate()
        close(fd)
    }
}
