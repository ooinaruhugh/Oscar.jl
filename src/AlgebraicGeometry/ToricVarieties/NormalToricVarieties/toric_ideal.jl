############################
# Computation of the toric ideal
############################

function binomial_exponents_to_ideal(R::MPolyRing, binoms::Union{AbstractMatrix, ZZMatrix})
    nvariables = ncols(binoms)
    @req nvariables == nvars(R) "Ring has wrong number of variables"
    if nrows(binoms) == 0
        return ideal([zero(R)])
    end
    terms = Vector{QQMPolyRingElem}(undef, nrows(binoms))
    for i in 1:nrows(binoms)
        binom = binoms[i, :]
        xpos = one(R)
        xneg = one(R)
        for j in 1:nvariables
            if binom[j] < 0
                xneg = xneg * R[j]^(-binom[j])
            elseif binom[j] > 0
                xpos = xpos * R[j]^(binom[j])
            end
        end
        terms[i] = xpos-xneg
    end
    return ideal(terms)
end


@doc raw"""
    binomial_exponents_to_ideal(binoms::Union{AbstractMatrix, ZZMatrix})

This function converts the rows of a matrix to binomials. Each row $r$ is
written as $r=u-v$ with $u, v\ge 0$ by splitting into positive and negative
entries. Then the row $r$ corresponds to $x^u-x^v$.  The resulting ideal is
returned.

# Examples
```jldoctest
julia> A = [-1 -1 0 2; 2 3 -2 -1]
2×4 Matrix{Int64}:
 -1  -1   0   2
  2   3  -2  -1

julia> binomial_exponents_to_ideal(A)
Ideal generated by
  -x1*x2 + x4^2
  x1^2*x2^3 - x3^2*x4
```
"""
function binomial_exponents_to_ideal(binoms::Union{AbstractMatrix, ZZMatrix})
    R, _ = polynomial_ring(QQ, ncols(binoms), cached=false)
    return binomial_exponents_to_ideal(R, binoms)
end


@doc raw"""
    toric_ideal(pts::ZZMatrix)

Return the toric ideal generated from the linear relations between the points
`pts`. This is the ideal generated by the set of binomials
$$\{x^u-x^v\ |\ u, v\in\mathbb{Z}^n_{\ge 0}\ (pts)^T\cdot(u-v) = 0\}$$

# Examples
```jldoctest
julia> C = positive_hull([-2 5; 1 0]);

julia> H = hilbert_basis(C);

julia> toric_ideal(H)
Ideal generated by
  x2*x3 - x4^2
  -x1*x3 + x2^2*x4
  -x1*x4 + x2^3
  -x1*x3^2 + x2*x4^3
  -x1*x3^3 + x4^5
```
"""
function toric_ideal(pts::ZZMatrix)
    n = nrows(pts)
    R, _ = polynomial_ring(QQ, n, cached=false)
    return toric_ideal(R, pts)
end

@doc raw"""
    toric_ideal(R::MPolyRing, pts::ZZMatrix)

Return the toric ideal generated from the linear relations between the points
`pts`. This is the ideal generated by the set of binomials
$$\{x^u-x^v\ |\ u, v\in\mathbb{Z}^n_{\ge 0}\ (pts)^T\cdot(u-v) = 0\}$$

# Examples
```jldoctest
julia> C = positive_hull([-2 5; 1 0]);

julia> H = hilbert_basis(C);

julia> R, _ = polynomial_ring(QQ, length(H));

julia> toric_ideal(R, H)
Ideal generated by
  x2*x3 - x4^2
  -x1*x3 + x2^2*x4
  -x1*x4 + x2^3
  -x1*x3^2 + x2*x4^3
  -x1*x3^3 + x4^5
```
"""
function toric_ideal(R::MPolyRing, pts::ZZMatrix)
    intkernel = kernel(pts, side=:left)
    presat = binomial_exponents_to_ideal(R, intkernel)
    J = ideal([prod(gens(base_ring(presat)))])
    return saturation(presat, J)
end

toric_ideal(pts::Union{AbstractMatrix,SubObjectIterator}) = toric_ideal(matrix(ZZ, pts))
toric_ideal(R::MPolyRing, pts::Union{AbstractMatrix,SubObjectIterator}) = toric_ideal(R, matrix(ZZ, pts))
