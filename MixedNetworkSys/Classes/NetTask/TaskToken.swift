//
//  TaskToken.swift
//  Alamofire
//
//  Created by jimmy on 2021/8/30.
//

import Foundation
import Alamofire

final class TaskToken: NetworkUploadTask, NetworkDownloadTask, NetworkDataTask {
    private(set) var taskIdentifier: Int
    
    private(set) var resumeAction: () -> Void
    private(set) var suspendAction: () -> Void
    private(set) var cancelAction: () -> Void
    
    private(set) var isCancelled = false
    private(set) var isRunning = false
    
    private let lock: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    func finished() {
        _ = lock.wait(timeout: DispatchTime.distantFuture)
        defer { lock.signal() }
        guard isRunning else { return }
        isRunning = false
    }
    
    func cancel() {
        _ = lock.wait(timeout: DispatchTime.distantFuture)
        defer { lock.signal() }
        guard !isCancelled else { return }
        isCancelled = true
        cancelAction()
    }
    
    func resume() {
        _ = lock.wait(timeout: DispatchTime.distantFuture)
        defer { lock.signal() }
        guard !isCancelled else { return }
        guard !isRunning else { return }
        isRunning = true
        resumeAction()
    }
    
    func suspend() {
        _ = lock.wait(timeout: DispatchTime.distantFuture)
        defer { lock.signal() }
        guard !isCancelled else { return }
        guard isRunning else { return }
        isRunning = false
        suspendAction()
    }
    
    init(
        resumeAction: @escaping () -> Void,
        suspendAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void,
        taskIdentifier: Int = UUID().uuidString.hashValue
    ) {
        self.resumeAction = resumeAction
        self.suspendAction = suspendAction
        self.cancelAction = cancelAction
        self.taskIdentifier = taskIdentifier
    }
    
    convenience init(requestTask: Request) {
        self.init(
            resumeAction: {
                requestTask.resume()
            },
            suspendAction: {
                requestTask.suspend()
            },
            cancelAction: {
                requestTask.cancel()
            },
            taskIdentifier: requestTask.id.uuidString.hashValue
        )
        
        if let requestTask = requestTask as? DownloadRequest {
            self.downloalCancelAction = { byProducingResumeData in
                requestTask.cancel(byProducingResumeData: { (data) in
                    byProducingResumeData(data)
                })
            }
        }
    }
    
    convenience init(){
        self.init(
            resumeAction: {
            },
            suspendAction: {
            },
            cancelAction: {
            }
        )
    }
    
    func restart(with task: NetworkDataTask) {
        taskIdentifier = task.taskIdentifier
        
        resumeAction = { task.resume() }
        suspendAction = { task.suspend() }
        cancelAction = { task.cancel() }
        
        isCancelled = false
        isRunning = false
        
        resume()
    }
    
    // MARK: - Download
    var downloalCancelAction: ((@escaping (Data?) -> Void) -> Void)?
    
    func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
        _ = lock.wait(timeout: DispatchTime.distantFuture)
        defer { lock.signal() }
        guard !isCancelled else { return }
        isCancelled = true
        downloalCancelAction?(completionHandler)
    }
}
