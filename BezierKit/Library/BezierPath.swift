//
//  BezierPath.swift
//  BezierKit
//
//  Created by Holmes Futrell on 7/31/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

public class Path {
    
    private class PathApplierFunctionContext {
        var currentPoint: CGPoint? = nil
        var subpathStartPoint: CGPoint? = nil
        var currentSubpath: [BezierCurve] = []
        var components: [PolyBezier] = []
    }
    
    lazy var cgPath: CGPath = {
        let mutablePath = CGMutablePath()
        for subpath in self.subpaths {
            mutablePath.addPath(subpath.cgPath)
        }
        return mutablePath.copy()!
    }()
    
    let subpaths: [PolyBezier]

    init(_ path: CGPath) {
        var context = PathApplierFunctionContext()
        func applierFunction(_ ctx: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) {
            guard let context = ctx?.assumingMemoryBound(to: PathApplierFunctionContext.self).pointee else {
                fatalError("unexpected applierFunction context")
            }
            let points: UnsafeMutablePointer<CGPoint> = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                // TODO: what happens if a path calls moveToPoint without calling closeSubpath?
                context.currentPoint = points[0]
                context.subpathStartPoint = points[0]
                context.currentSubpath = []
            case .addLineToPoint:
                let line = LineSegment(p0: context.currentPoint!, p1: points[0])
                context.currentSubpath.append(line)
                context.currentPoint = points[0]
            case .addQuadCurveToPoint:
                let quadCurve = QuadraticBezierCurve(p0: context.currentPoint!, p1: points[0], p2: points[1])
                context.currentSubpath.append(quadCurve)
                context.currentPoint = points[1]
            case .addCurveToPoint:
                let cubicCurve = CubicBezierCurve(p0: context.currentPoint!, p1: points[0], p2: points[1], p3: points[2])
                context.currentSubpath.append(cubicCurve)
                context.currentPoint = points[2]
            case .closeSubpath:
                if context.currentPoint != context.subpathStartPoint {
                    let line = LineSegment(p0: context.currentPoint!, p1: context.subpathStartPoint!)
                    context.currentSubpath.append(line)
                }
                context.components.append(PolyBezier(curves: context.currentSubpath))
                context.currentPoint = context.subpathStartPoint!
                context.currentSubpath = []
            }
        }
        let rawContextPointer = UnsafeMutableRawPointer(&context).bindMemory(to: PathApplierFunctionContext.self, capacity: 1)
        path.apply(info: rawContextPointer, function: applierFunction)
        subpaths = context.components
    }
}
