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
    private let half: Int
    private let size: Int
    private let scale: Int

    private var enties: [(Int, Int)]

    init(bytes: Int, scale: Int) {
        self.scale = scale
        let (fd, fp, half, bp) = Self.createSharedFrameBuffer(bytes: bytes)
        self.fd = fd
        self.half = half
        self.fp = fp.bindMemory(to: UInt32.self, capacity: half / 4)
        self.bp = bp.bindMemory(to: UInt32.self, capacity: half / 4)
        self.size = bytes
        self.enties = []
        for _ in 0..<25 {
            let dx = Int.random(in: 0...200)
            let dy = Int.random(in: 0...200)
            enties.append((dx, dy))
        }
    }

    mutating func update(width: Int, height: Int) {
        var new: [(Int, Int)] = []
        for (x, y) in enties {
            let dx = Int.random(in: -50...50)
            let dy = Int.random(in: -50...50)
            var by = y
            var bx = x

            if by + dy > height * scale {
                by = 0
            } else if by + dy <= 0 {
                by = height * scale
            } else {
                by = by + dy
            }
            if bx + dx > width * scale {
                bx = 0
            } else if bx + dx <= 0 {
                bx = width * scale
            } else {
                bx = bx + dx
            }
            new.append((bx, by))
        }
        self.enties = new
    }

    mutating func draw(_ side: Side, width: Int, height: Int) {
        let buffer: UnsafeMutablePointer<UInt32>
        switch side {
        case .front:
            buffer = fp
        case .back:
            buffer = bp
        }

        var foundEntity = false
        for x in 0..<width * scale {
            for y in 0..<height * scale {
                let i = (y * width * scale) + x
                for (bx, by) in enties {
                    let bxx = bx + 20
                    let byy = by + 20
                    if y > by && y < byy && x > bx && x < bxx {
                        buffer[i] = 0xFF_FF_00_00
                        foundEntity = true
                        break
                    }
                }
                if !foundEntity {
                    if y > 20 && y < 200 && x > 20 && x < 200 {
                        buffer[i] = 0xFF_00_FF_00
                    } else {
                        buffer[i] = 0xFF_00_FF_FF
                    }
                }
                foundEntity = false
            }
        }
    }

    private static func createSharedFrameBuffer(bytes: Int) -> (
        FD, UnsafeMutableRawPointer, Int, UnsafeMutableRawPointer
    ) {
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
