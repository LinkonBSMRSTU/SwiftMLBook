// a bit experimental layer for now. I think it works but I'm not 100%
// the gradient check is a bit funky. I'll look into this a bit later.
// Local Response Normalization in window, along depths of volumes
import Foundation

public struct LocalResponseNormalizationLayerOpt: LayerInOptProtocol {
    public var k: Float
    public var n: Float
    public var α: Float
    public var β: Float
    public var inSx: Int
    public var inSy: Int
    public var inDepth: Int
}

public class LocalResponseNormalizationLayer: HiddenLayer {
    
    public var k: Float = Float(0.0)
    public var n: Float = 0
    public var α: Float = Float(0.0)
    public var β: Float = Float(0.0)
    public var outSx: Int = 0
    public var outSy: Int = 0
    public var outDepth: Int = 0
    public var inAct: Volume?
    public var outAct: Volume?
    public var S_cache_: Volume?
    
    public init(opt: LocalResponseNormalizationLayerOpt) {
        
        // required
        k = opt.k
        n = opt.n
        α = opt.α
        β = opt.β
        
        // computed
        outSx = opt.inSx
        outSy = opt.inSy
        outDepth = opt.inDepth
        
        // checks
        if n.truncatingRemainder(dividingBy: 2) == 0 { print("WARNING n should be odd for LRN layer"); }
    }
    
    public func forward(_ V: inout Volume, isTraining: Bool) -> Volume {
        inAct = V
        
        let A = V.cloneAndZero()
        S_cache_ = V.cloneAndZero()
        let n2 = Int(floor(n/2))
        for x in 0 ..< V.sx {
            
            for y in 0 ..< V.sy {
                
                for i in 0 ..< V.depth {
                    
                    
                    let ai = V.get(x: x, y: y, d: i)
                    
                    // normalize in a window of size n
                    var den = Float(0.0)
                    for j in max(0, i-n2) ... min(i+n2, V.depth-1) {
                        let aa = V.get(x: x, y: y, d: j)
                        den += aa*aa
                    }
                    den *= α / n
                    den += k
                    S_cache_!.set(x: x, y: y, d: i, v: den) // will be useful for backprop
                    den = pow(den, β)
                    A.set(x: x, y: y, d: i, v: ai/den)
                }
            }
        }
        
        outAct = A
        return outAct! // dummy identity function for now
    }
    
    public func backward() -> () {
        // evaluate gradient wrt data
        guard let V = inAct, // we need to set dw of this
            let outAct = outAct,
            let S_cache_ = S_cache_
            else {
                fatalError("inAct or outAct or S_cache_ is nil")
        }
        
        V.dw = ArrayUtils.zerosFloat(V.w.count) // zero out gradient wrt data
        //        let A = outAct // computed in forward pass
        
        let n2 = Int(floor(n/2))
        for x in 0 ..< V.sx {
            
            for y in 0 ..< V.sy {
                
                for i in 0 ..< V.depth {
                    
                    
                    let chainGrad = outAct.getGrad(x: x, y: y, d: i)
                    let S = S_cache_.get(x: x, y: y, d: i)
                    let SB = pow(S, β)
                    let SB2 = SB*SB
                    
                    // normalize in a window of size n
                    for j in max(0, i-n2) ... min(i+n2, V.depth-1) {
                        let aj = V.get(x: x, y: y, d: j)
                        var g = -aj*β*pow(S, β-1)*α/n*2*aj
                        if j==i {
                            g += SB
                        }
                        g /= SB2
                        g *= chainGrad
                        V.addGrad(x: x, y: y, d: j, v: g)
                    }
                    
                }
            }
        }
    }
    
    public func getParamsAndGrads() -> [ParamsAndGrads] { return [] }
    
    public func assignParamsAndGrads(_ paramsAndGrads: [ParamsAndGrads]) ->() {
        
    }
}

