//
//  Proxy.swift
//  Aquifer
//
//  Created by Alexander Ronald Altman on 1/13/15.
//  Copyright (c) 2015 TypeLift. All rights reserved.
//

import Foundation
import Swiftz

internal enum ProxyRepr<UO, UI, DI, DO, FR> {
    case Request(() -> UO, UI -> ProxyRepr<UO, UI, DI, DO, FR>)
    case Respond(() -> DO, DI -> ProxyRepr<UO, UI, DI, DO, FR>)
    case Pure(() -> FR)

    internal func fmap<NR>(f: FR -> NR) -> ProxyRepr<UO, UI, DI, DO, NR> {
        switch self {
        case let Request(uO, fUI): return ProxyRepr<UO, UI, DI, DO, NR>.Request(uO) { fUI($0).fmap(f) }
        case let Respond(dO, fDI): return ProxyRepr<UO, UI, DI, DO, NR>.Respond(dO) { fDI($0).fmap(f) }
        case let Pure(x): return ProxyRepr<UO, UI, DI, DO, NR>.Pure { _ in f(x()) }
        }
    }

    internal func ap<NR>(f: ProxyRepr<UO, UI, DI, DO, FR -> NR>) -> ProxyRepr<UO, UI, DI, DO, NR> {
        switch f {
        case let Request(uO, fUI): return ProxyRepr<UO, UI, DI, DO, NR>.Request(uO) { self.ap(fUI($0)) }
        case let Respond(dO, fDI): return ProxyRepr<UO, UI, DI, DO, NR>.Respond(dO) { self.ap(fDI($0)) }
        case let Pure(g): return self.fmap(g())
        }
    }

    internal func bind<NR>(f: FR -> ProxyRepr<UO, UI, DI, DO, NR>) -> ProxyRepr<UO, UI, DI, DO, NR> {
        switch self {
        case let Request(uO, fUI): return ProxyRepr<UO, UI, DI, DO, NR>.Request(uO) { fUI($0).bind(f) }
        case let Respond(dO, fDI): return ProxyRepr<UO, UI, DI, DO, NR>.Respond(dO) { fDI($0).bind(f) }
        case let Pure(x): return f(x())
        }
    }

    internal func reflect() -> ProxyRepr<DO, DI, UI, UO, FR> {
        switch self {
        case let Request(uO, fUI): return ProxyRepr<DO, DI, UI, UO, FR>.Respond(uO) { fUI($0).reflect() }
        case let Respond(dO, fDI): return ProxyRepr<DO, DI, UI, UO, FR>.Request(dO) { fDI($0).reflect() }
        case let Pure(x): return ProxyRepr<DO, DI, UI, UO, FR>.Pure(x)
        }
    }
}

/// A bidirectional channel for information.
///
/// The type parameters are as follows:
/// UO - upstream   output
/// UI - upstream   input
/// DI — downstream input
/// DO — downstream output
/// FR — final      result
public struct Proxy<UO, UI, DI, DO, FR> {
    internal let repr: ProxyRepr<UO, UI, DI, DO, FR>

    internal init(_ r: ProxyRepr<UO, UI, DI, DO, FR>) {
        repr = r
    }
}

extension Proxy: Functor {
    typealias B = Any

    public func fmap<NR>(f: FR -> NR) -> Proxy<UO, UI, DI, DO, NR> {
        return Proxy<UO, UI, DI, DO, NR>(repr.fmap(f))
    }
}

public func <^><UO, UI, DI, DO, FR, NR>(f: FR -> NR, p: Proxy<UO, UI, DI, DO, FR>) -> Proxy<UO, UI, DI, DO, NR> {
    return p.fmap(f)
}

public prefix func <^><UO, UI, DI, DO, FR, NR>(p: Proxy<UO, UI, DI, DO, FR> ) -> (FR -> NR) -> Proxy<UO, UI, DI, DO, NR> {
    return { f in p.fmap(f) }
}

public postfix func <^><UO, UI, DI, DO, FR, NR>(f: FR -> NR) -> Proxy<UO, UI, DI, DO, FR> -> Proxy<UO, UI, DI, DO, NR> {
    return { p in p.fmap(f) }
}

extension Proxy: Pointed {
    public static func pure(x: FR) -> Proxy<UO, UI, DI, DO, FR> {
        return Proxy(ProxyRepr.Pure { _ in x })
    }
}

public func pure<UO, UI, DI, DO, FR>(x: FR) -> Proxy<UO, UI, DI, DO, FR> {
    return Proxy.pure(x)
}

extension Proxy: Applicative {
    public func ap<NR>(f: Proxy<UO, UI, DI, DO, FR -> NR>) -> Proxy<UO, UI, DI, DO, NR> {
        return Proxy<UO, UI, DI, DO, NR>(repr.ap(f.repr))
    }
}

public func <*><UO, UI, DI, DO, FR, NR>(f: Proxy<UO, UI, DI, DO, FR -> NR>, p: Proxy<UO, UI, DI, DO, FR>) -> Proxy<UO, UI, DI, DO, NR> {
    return p.ap(f)
}

public prefix func <*><UO, UI, DI, DO, FR, NR>(p: Proxy<UO, UI, DI, DO, FR>) -> Proxy<UO, UI, DI, DO, FR -> NR> -> Proxy<UO, UI, DI, DO, NR> {
    return { f in p.ap(f) }
}

public postfix func <*><UO, UI, DI, DO, FR, NR>(f: Proxy<UO, UI, DI, DO, FR -> NR>) -> Proxy<UO, UI, DI, DO, FR> -> Proxy<UO, UI, DI, DO, NR> {
    return { p in p.ap(f) }
}

extension Proxy: Monad {
    public func bind<NR>(f: FR -> Proxy<UO, UI, DI, DO, NR>) -> Proxy<UO, UI, DI, DO, NR> {
        return Proxy<UO, UI, DI, DO, NR>(repr.bind { f($0).repr })
    }
}

public func >>-<UO, UI, DI, DO, FR, NR>(p: Proxy<UO, UI, DI, DO, FR>, f: FR -> Proxy<UO, UI, DI, DO, NR>) -> Proxy<UO, UI, DI, DO, NR> {
    return p.bind(f)
}

public prefix func >>-<UO, UI, DI, DO, FR, NR>(f: FR -> Proxy<UO, UI, DI, DO, NR>) -> Proxy<UO, UI, DI, DO, FR> -> Proxy<UO, UI, DI, DO, NR> {
    return { p in p.bind(f) }
}

public postfix func >>-<UO, UI, DI, DO, FR, NR>(p: Proxy<UO, UI, DI, DO, FR>) -> (FR -> Proxy<UO, UI, DI, DO, NR>) -> Proxy<UO, UI, DI, DO, NR> {
    return { f in p.bind(f) }
}

extension Proxy {
    public func reflect() -> Proxy<DO, DI, UI, UO, FR> {
        return Proxy<DO, DI, UI, UO, FR>(repr.reflect())
    }
}

internal func closed<A>(x: () -> X) -> A {
    return x().absurd()
}

public func runEffect<FR>(p: Proxy<X, (), (), X, FR>) -> FR {
    switch p.repr {
    case let .Request(uO, _): return closed(uO)
    case let .Respond(dO, _): return closed(dO)
    case let .Pure(x): return x()
    }
}
