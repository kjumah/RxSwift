//
//  RuntimeStateSnapshot.swift
//  RxTests
//
//  Created by Krunoslav Zaher on 11/27/15.
//
//

import Foundation

class ObjectRuntimeState {
    let real: ClassRuntimeState
    let actingAs: ClassRuntimeState

    init(target: AnyObject) {
        assert(object_getClass(target) == target.dynamicType)
        real = ClassRuntimeState(object_getClass(target))
        actingAs = ClassRuntimeState(RXObjCTestRuntime.objCClass(target))
    }

    /*func isForwardingSelector(selector: Selector) -> Bool {
        if let implementation = real.implementations[selector] {
            return RXObjCTestRuntime.isForwardingIMP(implementation)
        }
        else {
            return false
        }
    }*/

    private static func changesFrom(from: ClassRuntimeState, to: ClassRuntimeState) -> [ObjectRuntimeChange] {
        if from.targetClass == to.targetClass {
            var changes = [ObjectRuntimeChange]()
            for (selector, implementation) in to.implementations {
                if let originalImplementation = from.implementations[selector] {
                    if originalImplementation != implementation {
                        if RXObjCTestRuntime.isForwardingIMP(implementation) {
                            changes.append(.ImplementationChangedToForwarding(forSelector: selector))
                        }
                        else {
                            changes.append(.ImplementationChanged(forSelector: selector))
                        }
                    }
                }
                else {
                    if RXObjCTestRuntime.isForwardingIMP(implementation) {
                        changes.append(.ForwardImplementationAdded(forSelector: selector))
                    }
                    else {
                        changes.append(.ImplementationAdded(forSelector: selector))
                    }
                }
            }

            for (oldSelector, _) in from.implementations {
                if to.implementations[oldSelector] == nil {
                    changes.append(.ImplementationDeleted(forSelector: oldSelector))
                }
            }
            return changes
        }
        else {
            return [.ClassChanged(from: NSStringFromClass(from.targetClass), to: NSStringFromClass(to.targetClass), andImplementsTheseSelectors: Array(to.implementations.keys))]
        }
    }

    func changesFrom(initialState: ObjectRuntimeState) -> (real: [ObjectRuntimeChange], actingAs: [ObjectRuntimeChange]) {
        return (
            real: ObjectRuntimeState.changesFrom(initialState.real, to: self.real),
            actingAs: ObjectRuntimeState.changesFrom(initialState.actingAs, to: self.actingAs)
        )
    }
}

enum ObjectRuntimeChange : Hashable {
    static func ClassChangedToDynamic(from: String, andImplementsTheseSelectors: [Selector]) -> ObjectRuntimeChange {
        return .ClassChanged(from: from, to: "_RX_namespace_" + from, andImplementsTheseSelectors: andImplementsTheseSelectors)
    }

    case ClassChanged(from: String, to: String, andImplementsTheseSelectors: [Selector])
    case ImplementationChanged(forSelector: Selector)
    case ImplementationChangedToForwarding(forSelector: Selector)
    case ImplementationAdded(forSelector: Selector)
    case ImplementationDeleted(forSelector: Selector)
    case ForwardImplementationAdded(forSelector: Selector)
}

extension ObjectRuntimeChange {
    var hashValue: Int {
        // who cares, this is not performance critical
        return 0
    }
}

func ==(lhs: ObjectRuntimeChange, rhs: ObjectRuntimeChange) -> Bool {
    switch (lhs, rhs) {
    case let (.ClassChanged(lFrom, lTo, lImplementations), .ClassChanged(rFrom, rTo, rImplementations)):
        return (lFrom == rFrom && lTo == rTo) && Set(lImplementations) == Set(rImplementations)
    case let (.ImplementationChanged(lSelector), .ImplementationChanged(rSelector)):
        return lSelector == rSelector
    case let (.ImplementationChangedToForwarding(lSelector), .ImplementationChangedToForwarding(rSelector)):
        return lSelector == rSelector
    case let (.ImplementationAdded(lSelector), .ImplementationAdded(rSelector)):
        return lSelector == rSelector
    case let (.ImplementationDeleted(lSelector), .ImplementationDeleted(rSelector)):
        return lSelector == rSelector
    case let (.ForwardImplementationAdded(lSelector), .ForwardImplementationAdded(rSelector)):
        return lSelector == rSelector
    default:
        return false
    }
}

extension SequenceType where Generator.Element == ObjectRuntimeChange {
    var classChanged: Bool {
        return self.filter { x in
            if case .ClassChanged = x {
                return true
            } else {
                return false
            }
        }.count > 0
    }
}

struct ClassRuntimeState {
    let targetClass: AnyClass
    let implementations: [Selector: IMP]

    init(_ targetClass: AnyClass) {
        self.targetClass = targetClass
        self.implementations = ClassRuntimeState.implementationsBySelector(targetClass)
    }

    static func implementationsBySelector(klass: AnyClass) -> [Selector: IMP] {
        var count: UInt32 = 0
        let methods = class_copyMethodList(klass, &count)

        var result = [Selector: IMP]()
        for i in 0 ..< count {
            let method: Method = methods.advancedBy(Int(i)).memory
            result[method_getName(method)] = method_getImplementation(method)
        }

        return result
    }

}
