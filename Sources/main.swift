import Dispatch

class Worker {
    let mQueue: DispatchQueue
    let mSemaphore: DispatchSemaphore
    let mInterval: Int
    static let mBufferQueue = DispatchQueue(label: "Buffer Queue")
    var mBuffer = Array<Int>()

    internal var mConnector: Worker? = nil

    init(_ label: String, bufferCount: Int, interval: Int) {
        mQueue = DispatchQueue(label: label)
        mSemaphore = DispatchSemaphore(value: bufferCount)
        mInterval = interval
    }

    func sendData(_ value: Int) {
        Worker.mBufferQueue.async {
            self.mBuffer.append(value)
            self.mSemaphore.signal()
        }
    }

    func setConnector(_ connector: Worker) {
        mConnector = connector
    }

    func start() {
        mQueue.asyncAfter(deadline: .now() + .milliseconds(mInterval), execute: self.execute)                    
    }

    func execute() {
        run()
        start()
    }

    func run() {}
}

class DemuxeWorker : Worker {
    var mCount: Int = 0

    override func run() {
        mSemaphore.wait()
        mConnector!.sendData(mCount)
        print("Demuxer: ", mCount)
        mCount += 1
    }
}

class CodecWorker : Worker {
    override func run() {
        mSemaphore.wait()
        var value = 0
        Worker.mBufferQueue.sync {
            value = mBuffer[0]
            mBuffer.remove(at: 0)
        }
        print("Codec = ", value)
        mConnector!.sendData(0)
    }
}

let demuxer = DemuxeWorker("Demuxe Worker", bufferCount: 10, interval: 0)
let decoder = CodecWorker("Codec Worker", bufferCount: 0, interval: 100)

demuxer.setConnector(decoder)
decoder.setConnector(demuxer)

demuxer.start()
decoder.start()    

Dispatch.dispatchMain()