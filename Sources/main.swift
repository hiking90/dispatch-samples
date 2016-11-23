import Dispatch

class Worker {
    static let mQueue = DispatchQueue(label: "Worker Queue", attributes: .concurrent)
    static let mBufferQueue = DispatchQueue(label: "Buffer Queue")

    let mSemaphore: DispatchSemaphore
    let mInterval: Int
    var mBuffer = Array<Int>()

    internal var connector: Worker? = nil

    init(_ label: String, bufferCount: Int, interval: Int) {
        mSemaphore = DispatchSemaphore(value: bufferCount)
        mInterval = interval
    }

    func sendData(_ value: Int) {
        Worker.mBufferQueue.async {
            self.mBuffer.append(value)
            self.mSemaphore.signal()
        }
    }

    func start() {
        Worker.mQueue.asyncAfter(deadline: .now() + .milliseconds(mInterval), execute: self.execute)                    
    }

    func execute() {
        run()
        start()
    }

    func run() {}
}

class DemuxeWorker: Worker {
    var mCount: Int = 0

    override func run() {
        mSemaphore.wait()
        connector!.sendData(mCount)
        print("Demuxer: ", mCount)
        mCount += 1
    }
}

class CodecWorker: Worker {
    override func run() {
        mSemaphore.wait()
        var value = 0
        Worker.mBufferQueue.sync {
            value = mBuffer[0]
            mBuffer.remove(at: 0)
        }
        print("Codec = ", value)
        connector!.sendData(0)
    }
}

let demuxer = DemuxeWorker("Demuxe Worker", bufferCount: 10, interval: 0)
let decoder = CodecWorker("Codec Worker", bufferCount: 0, interval: 100)

demuxer.connector = decoder
decoder.connector = demuxer

demuxer.start()
decoder.start()

DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
    Worker.mQueue.suspend()
}

Dispatch.dispatchMain()