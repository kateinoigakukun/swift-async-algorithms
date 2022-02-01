//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Async Algorithms open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import XCTest
import AsyncAlgorithms

final class TestSubject: XCTestCase {
  func test_subject() async {
    let subject = AsyncSubject<String>()
    Task {
      await subject.send("test1")
    }
    Task {
      await subject.send("test2")
    }
    
    let t: Task<String?, Never> = Task {
      var iterator = subject.makeAsyncIterator()
      let value = await iterator.next()
      return value
    }
    var iterator = subject.makeAsyncIterator()
    let value = await iterator.next()
    let other = await t.value
    
    XCTAssertEqual(Set([value, other]), Set(["test1", "test2"]))
  }
  
  func test_throwing_subject() async throws {
    let subject = AsyncThrowingSubject<String, Error>()
    Task {
      await subject.send("test1")
    }
    Task {
      await subject.send("test2")
    }
    
    let t: Task<String?, Error> = Task {
      var iterator = subject.makeAsyncIterator()
      let value = try await iterator.next()
      return value
    }
    var iterator = subject.makeAsyncIterator()
    let value = try await iterator.next()
    let other = try await t.value
    
    XCTAssertEqual(Set([value, other]), Set(["test1", "test2"]))
  }
  
  func test_throwing() async {
    let subject = AsyncThrowingSubject<String, Error>()
    Task {
      await subject.fail(Failure())
    }
    var iterator = subject.makeAsyncIterator()
    do {
      let _ = try await iterator.next()
      XCTFail()
    } catch {
      XCTAssertEqual(error as? Failure, Failure())
    }
  }
  
  func test_send_finish() async {
    let subject = AsyncSubject<String>()
    let complete = ManagedCriticalState(false)
    let finished = expectation(description: "finished")
    Task {
      await subject.finish()
      complete.withCriticalRegion { $0 = true }
      finished.fulfill()
    }
    XCTAssertFalse(complete.withCriticalRegion { $0 })
    let value = ManagedCriticalState<String?>(nil)
    let received = expectation(description: "received")
    let pastEnd = expectation(description: "pastEnd")
    Task {
      var iterator = subject.makeAsyncIterator()
      let ending = await iterator.next()
      value.withCriticalRegion { $0 = ending }
      received.fulfill()
      let item = await iterator.next()
      XCTAssertNil(item)
      pastEnd.fulfill()
    }
    wait(for: [finished, received], timeout: 1.0)
    XCTAssertTrue(complete.withCriticalRegion { $0 })
    XCTAssertEqual(value.withCriticalRegion { $0 }, nil)
    wait(for: [pastEnd], timeout: 1.0)
    let additionalSend = expectation(description: "additional send")
    Task {
      await subject.send("test")
      additionalSend.fulfill()
    }
    wait(for: [additionalSend], timeout: 1.0)
  }
  
  func test_cancellation() async {
    let subject = AsyncSubject<String>()
    let ready = expectation(description: "ready")
    let task: Task<String?, Never> = Task {
      var iterator = subject.makeAsyncIterator()
      ready.fulfill()
      return await iterator.next()
    }
    wait(for: [ready], timeout: 1.0)
    task.cancel()
    let value = await task.value
    XCTAssertNil(value)
  }
  
  func test_cancellation_throwing() async throws {
    let subject = AsyncThrowingSubject<String, Error>()
    let ready = expectation(description: "ready")
    let task: Task<String?, Error> = Task {
      var iterator = subject.makeAsyncIterator()
      ready.fulfill()
      return try await iterator.next()
    }
    wait(for: [ready], timeout: 1.0)
    task.cancel()
    let value = try await task.value
    XCTAssertNil(value)
  }
}
