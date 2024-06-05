@doc raw"""
    generic_walk(G::Oscar.IdealGens, start::MonomialOrdering, target::MonomialOrdering)

Compute a reduced Groebner basis w.r.t. to a monomial order by converting it using the Groebner Walk
using the algorithm proposed by Collart, Kalkbrener & Mall (1997).

# Arguments
- `G::Oscar.IdealGens`: Groebner basis of an ideal with respect to a starting monomial order.
- `target::MonomialOrdering`: monomial order one wants to compute a Groebner basis for.
- `start::MonomialOrdering`: monomial order to begin the conversion.
"""
function generic_walk(G::Oscar.IdealGens, start::MonomialOrdering, target::MonomialOrdering)
  @vprintln :groebner_walk "Results for generic_walk"
  @vprintln :groebner_walk "Facets crossed for: "

  Lm = leading_term.(G, ordering = start)
  MG = MarkedGroebnerBasis(gens(G), Lm)
  v = next_gamma(MG, ZZ.([0]), start, target)

  @v_do :groebner_walk steps = 0
  while !isempty(v)
    @vprintln :groebner_walk v
    MG = generic_step(MG, v, target)
    v = next_gamma(MG, v, start, target)

    @v_do :groebner_walk steps += 1
    @vprintln :groebner_walk 2 G
    @vprintln :groebner_walk 2 "======="
  end

  @vprint :groebner_walk "Cones crossed: "
  @vprintln :groebner_walk steps
  return gens(MG)
end

@doc raw"""
    generic_step(MG::MarkedGroebnerBasis, v::Vector{ZZRingElem}, ord::MonomialOrdering)

Given the marked Gröbner basis `MG` and a facet normal vector `v`, compute the next marked Gröbner basis.
"""
function generic_step(MG::MarkedGroebnerBasis, v::Vector{ZZRingElem}, ord::MonomialOrdering)
  facet_Generators = facet_initials(MG, v)
  H = groebner_basis(
    ideal(facet_Generators); ordering=ord, complete_reduction=true, algorithm=:buchberger
  )

  @vprint :groebner_walk 5 "Initials forms of facet: "
  @vprintln :groebner_walk 5 facet_Generators

  @vprint :groebner_walk 3 "GB of initial forms: "
  @vprintln :groebner_walk 3 H

  H = MarkedGroebnerBasis(gens(H), leading_term.(H; ordering = ord))

  lift_generic!(H, MG)
  autoreduce!(H)

  return H
end

@doc raw"""
    difference_lead_tail(MG::MarkedGroebnerBasis)

Computes $a - b$ for $a$ a leading exponent and $b$ in the tail of some $g\in MG$. 
"""
function difference_lead_tail(MG::MarkedGroebnerBasis)
  (G,Lm) = gens(MG), markings(MG)
  lead_exp = leading_exponent_vector.(Lm)
  
  v = [ [l-t for t in T] for (l, T) in zip(lead_exp, exponents.(G)) ]
  
  return [ZZ.(v)./ZZ(gcd(v)) for v in unique!(reduce(vcat, v)) if !iszero(v)]
end

@doc raw"""
    next_gamma(
      MG::MarkedGroebnerBasis, w::Vector{ZZRingElem}, start::MonomialOrdering, target::MonomialOrdering
    )

Given a marked Gröbner basis `MG`, a weight vector `w` and monomial orderings `start` and `target`,
returns the "next" facet normal, i.e. the bounding vector $v$ fulfilling $w<v$ and being minimal with respect to the facet preorder $<$.
"""
function next_gamma(
    MG::MarkedGroebnerBasis, w::Vector{ZZRingElem}, start::MonomialOrdering, target::MonomialOrdering
  )
    V = filter_by_ordering(start, target, difference_lead_tail(MG))
    if w != ZZ.([0]) 
        V = filter_lf(w, start, target, V)
    end
    if isempty(V)
        return V
    end

    minV = first(V)
    for v in V 
        if facet_less_than(canonical_matrix(start), canonical_matrix(target),v, minV)
            minV = v
        end
    end
    return minV 
end

@doc raw"""
    facet_initials(MG::MarkedGroebnerBasis, v::Vector{ZZRingElem})

Given a marked Gröbner basis `MG` and a facet normal `v`, computes the Gröbner basis of initial forms 
of `MG` by truncating to all bounding vectors parallel to `v`.
"""
function facet_initials(MG::MarkedGroebnerBasis, v::Vector{ZZRingElem})
  R = base_ring(MG)
  inwG = Vector{MPolyRingElem}()

  ctx = MPolyBuildCtx(R)
  for (g, m) in gens_and_markings(MG)
    c, a = leading_coefficient_and_exponent(m)
    push_term!(ctx, c, a)

    for (d, b) in coefficients_and_exponents(g)
      if is_parallel(ZZ.(a - b), v)
        push_term!(ctx, d, b)
      end
    end

    push!(inwG, finish(ctx))
  end

  return inwG
end

@doc raw"""
    lift_generic(MG::MarkedGroebnerBasis, H::MarkedGroebnerBasis)

Given a marked Gröbner basis `MG` generating an ideal $I$ and a reduced marked Gröbner basis `H` of initial forms,
lift H to a marked Gröbner basis of I (with unknown ordering) by subtracting initial forms according to Fukuda, 2007.
"""
function lift_generic(MG::MarkedGroebnerBasis, H::MarkedGroebnerBasis)
  for i in 1:length(H.gens)
    H.gens[i] = H.gens[i] - normal_form(H.gens[i], MG)
    end
  return H
end

@doc raw"""
    lift_generic(MG::MarkedGroebnerBasis, H::MarkedGroebnerBasis)

Given a marked Gröbner basis `MG` generating an ideal $I$ and a reduced marked Gröbner basis `H` of initial forms,
lift H to a marked Gröbner basis of I (with unknown ordering) by subtracting initial forms according to Fukuda, 2007.
This changes `H` in-place.
"""
function lift_generic!(H::MarkedGroebnerBasis, MG::MarkedGroebnerBasis)
  for i in 1:length(H.gens)
    H.gens[i] = H.gens[i] - normal_form(H.gens[i], MG)
    end
  return H
end

@doc raw"""
    less_than_zero(M::ZZMatrix, v::Vector{ZZRingElem})

Checks whether  $Mv <_{\mathrm{lex}} 0$.
"""
function less_than_zero(M::ZZMatrix, v::Vector{ZZRingElem})
  if is_zero(v)
    return false
  else
    i = 1
  end
  while dot(M[i, :], v) == 0
    i += 1
  end
  return dot(M[i, :], v) < 0
end
  
  
@doc raw"""
    filter_by_ordering(start::MonomialOrdering, target::MonomialOrdering, V::Vector{Vector{ZZRingElem}})

Computes all elements $v\in V$ with $0 <_{\texttt{target}} v$ and $v <_{\texttt{start}} 0$
"""
function filter_by_ordering(start::MonomialOrdering, target::MonomialOrdering, V::Vector{Vector{ZZRingElem}})
  pred = v -> (
    less_than_zero(canonical_matrix(target), ZZ.(v)) && !less_than_zero(canonical_matrix(start), ZZ.(v))
  )
  return unique!(filter(pred, V))
end

@doc raw"""
    matrix_less_than(M::ZZMatrix, v::Vector{ZZRingElem}, w::Vector{ZZRingElem})

Returns true if $Mv < Mw$ lexicographically, false otherwise.
"""
function matrix_lexicographic_less_than(M::ZZMatrix, v::Vector{ZZRingElem}, w::Vector{ZZRingElem})
    i = 1
    while dot(M[i, :], v) == dot(M[i, :], w) && i != number_of_rows(M) 
        i += 1 
    end
    return dot(M[i, :], v) < dot(M[i, :], w)
end

#Comment: It may make more sense to have the monomial orderings as inputs.
@doc raw"""
    facet_less_than(S::ZZMatrix, T::ZZMatrix, u::Vector{ZZRingElem}, v::Vector{ZZRingElem})

Returns true if $u < v$with respect to the facet preorder $<$. (cf. "The generic Gröbner walk" (Fukuda et a;. 2007), pg. 10)
"""
function facet_less_than(S::ZZMatrix, T::ZZMatrix, u::Vector{ZZRingElem}, v::Vector{ZZRingElem})
    i = 1
    while dot(T[i,:], u)v == dot(T[i,:], v)u && i != number_of_rows(T)
        i += 1
    end
    return matrix_lexicographic_less_than(S, dot(T[i,:], u)v, dot(T[i,:], v)u) 
end

#returns all elements of V smaller than w w.r.t the facet preorder

@doc raw"""
    filter_lf(w::Vector{ZZRingElem}, start::MonomialOrdering, target::MonomialOrdering, V::Vector{Vector{ZZRingElem}})

Returns all elements of `V` smaller than `w` with respect to the facet preorder.
"""
function filter_lf(
        w::Vector{ZZRingElem}, 
        start::MonomialOrdering, target::MonomialOrdering, 
        V::Vector{Vector{ZZRingElem}}
    )
    skip_indices = facet_less_than.(
      Ref(canonical_matrix(start)),
      Ref(canonical_matrix(target)),
      Ref(w),
      V
    )

    return unique!(V[skip_indices])
end

@doc raw"""
    is_parallel(u::Vector{ZZRingElem}, v::Vector{ZZRingElem})

Determines whether $u$ and $v$ are non-zero integer multiples of each other.
"""
function is_parallel(u::Vector{ZZRingElem}, v::Vector{ZZRingElem})
  return !iszero(v) && !iszero(u) && u./gcd(u) == v./gcd(v)
end

#TODO: add tests 
