//
//  TaskToken.swift
//  MixedNetworkSys
//
//  Created by zf on 2021/8/22.
//

import Foundation

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

  convenience init(sessionTask: URLSessionTask) {
    self.init(
      resumeAction: {
        sessionTask.resume()
      },
      suspendAction: {
        sessionTask.suspend()
      },
      cancelAction: {
        sessionTask.cancel()
      },
      taskIdentifier: sessionTask.taskIdentifier
    )

    if let sessionTask = sessionTask as? URLSessionDownloadTask {
      self.downloalCancelAction = { byProducingResumeData in
        sessionTask.cancel(byProducingResumeData: { (data) in
          byProducingResumeData(data)
        })
      }
    }
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

  class func stubTask() -> TaskToken {
    return TaskToken(
      resumeAction: {
      },
      suspendAction: {
      },
      cancelAction: {
      }
    )
  }

  class func simpleTask() -> TaskToken {
    return TaskToken(
      resumeAction: {
      },
      suspendAction: {
      },
      cancelAction: {
      }
    )
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
