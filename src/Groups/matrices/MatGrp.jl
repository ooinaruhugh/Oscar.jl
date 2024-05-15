matrix_group(F::Ring, m::Int) = MatrixGroup{elem_type(F), dense_matrix_type(elem_type(F))}(F, m)

# build a MatrixGroup given a list of generators, given as array of either MatrixGroupElem or AbstractAlgebra matrices
"""
    matrix_group(R::Ring, m::Int, V::T...) where T<:Union{MatElem,MatrixGroupElem}
    matrix_group(R::Ring, m::Int, V::AbstractVector{T}) where T<:Union{MatElem,MatrixGroupElem}
    matrix_group(V::T...) where T<:Union{MatElem,MatrixGroupElem}
    matrix_group(V::AbstractVector{T}) where T<:Union{MatElem,MatrixGroupElem}

Return the matrix group generated by matrices in `V`. If the degree `m` and
coefficient ring `R` are not given, then `V` must be non-empty
"""
function matrix_group(F::Ring, m::Int, V::AbstractVector{T}; check::Bool=true) where T<:Union{MatElem,AbstractMatrixGroupElem}
   @req all(v -> size(v) == (m,m), V) "Matrix group generators must all be square and of equal degree"
   @req all(v -> base_ring(v) == F, V) "Matrix group generators must have the same base ring"

   # if T <: MatrixGroupElem, we can already assume that det(V[i]) != 0
   if T<:MatElem && check
     @req all(v -> is_unit(det(v)), V) "Matrix group generators must be invertible over their base ring"
   end

   G = matrix_group(F, m)
   L = Vector{elem_type(G)}(undef, length(V))
   for i in 1:length(V)
      if T<:MatElem
         L[i] = MatrixGroupElem(G,V[i])
      else
# TODO: this part of code from here
         if isdefined(V[i],:elm)
            if isdefined(V[i],:X)
               L[i] = MatrixGroupElem(G,matrix(V[i]),V[i].X)
            else
               L[i] = MatrixGroupElem(G,matrix(V[i]))
            end
         else
            L[i] = MatrixGroupElem(G,V[i].X)
         end
# to here

# can be replaced by the following line once deepcopy works for GAP objects
# > L[i] = deepcopy(V[i]); L[i].parent = G;
      end
   end
   G.gens = L

   return G
end

matrix_group(R::Ring, m::Int, V::Union{MatElem,MatrixGroupElem}...; check::Bool=true) = matrix_group(R, m, collect(V); check)

matrix_group(V::AbstractVector{T}; check::Bool=true) where T<:Union{MatElem,MatrixGroupElem} = matrix_group(base_ring(V[1]), nrows(V[1]), V; check)

matrix_group(V::Union{MatElem,MatrixGroupElem}...; check::Bool=true) = matrix_group(collect(V); check)

# For `general_linear_group` etc. the degree comes first, so we should also provide that option
matrix_group(m::Int, R::Ring) = matrix_group(R, m)
matrix_group(m::Int, R::Ring, V; check::Bool = true) = matrix_group(R, m, V, check = check)


# `MatrixGroup`: compare types, dimensions, and coefficient rings
function check_parent(G::T, g::GAPGroupElem) where T <: MatrixGroup
  P = g.parent
  return T === typeof(P) && G.deg == P.deg && G.ring == P.ring
end

function _as_subgroup_bare(G::MatrixGroup, H::GapObj)
  H1 = typeof(G)(base_ring(G), degree(G))
  H1.ring_iso = _ring_iso(G)
  H1.X = H
  return H1
end

MatrixGroupElem(G::MatrixGroup{RE,T}, x::T, x_gap::GapObj) where {RE,T} = MatrixGroupElem{RE,T}(G, x, x_gap)

MatrixGroupElem(G::MatrixGroup{RE,T}, x::T) where {RE, T} = MatrixGroupElem{RE,T}(G,x)
MatrixGroupElem(G::MatrixGroup{RE,T}, x_gap::GapObj) where {RE, T} = MatrixGroupElem{RE,T}(G,x_gap)

ring_elem_type(::Type{MatrixGroup{S,T}}) where {S,T} = S
mat_elem_type(::Type{MatrixGroup{S,T}}) where {S,T} = T
_gap_filter(::Type{<:MatrixGroup}) = GAP.Globals.IsMatrixGroup

elem_type(::Type{MatrixGroup{S,T}}) where {S,T} = MatrixGroupElem{S,T}
Base.eltype(::Type{MatrixGroup{S,T}}) where {S,T} = MatrixGroupElem{S,T}

# `parent_type` is defined and documented in AbstractAlgebra.
parent_type(::Type{MatrixGroupElem{S,T}}) where {S,T} = MatrixGroup{S,T}


function Base.deepcopy_internal(x::MatrixGroupElem, dict::IdDict)
  if isdefined(x, :X)
    X = Base.deepcopy_internal(x.X, dict)
    if isdefined(x, :elm)
      elm = Base.deepcopy_internal(matrix(x), dict)
      return MatrixGroupElem(x.parent, elm, X)
    else
      return MatrixGroupElem(x.parent, X)
    end
  elseif isdefined(x, :elm)
    elm = Base.deepcopy_internal(matrix(x), dict)
    return MatrixGroupElem(x.parent, elm)
  end
  error("$x has neither :X nor :elm")
end

change_base_ring(R::Ring, G::MatrixGroup) = map_entries(R, G)

########################################################################
#
# Basic
#
########################################################################

function _print_matrix_group_desc(io::IO, x::MatrixGroup)
  io = pretty(io)
  print(io, LowercaseOff(), string(x.descr), "(", x.deg ,",")
  if x.descr==:GU || x.descr==:SU
    print(io, characteristic(x.ring)^(div(degree(x.ring),2)),")")
  elseif x.ring isa Field && is_finite(x.ring)
    print(io, order(x.ring),")")
  else
    print(terse(io), x.ring)
    print(io ,")")
  end
end

function Base.show(io::IO, ::MIME"text/plain", x::MatrixGroup)
  isdefined(x, :descr) && return _print_matrix_group_desc(io, x)
  println(io, "Matrix group of degree ", degree(x))
  io = pretty(io)
  print(io, Indent())
  print(io, "over ", Lowercase(), base_ring(x))
  print(io, Dedent())
end

function Base.show(io::IO, x::MatrixGroup)
  @show_name(io, x)
  @show_special(io, x)
  isdefined(x, :descr) && return _print_matrix_group_desc(io, x)
  print(io, "Matrix group")
  if !is_terse(io)
    print(io, " of degree ", degree(x))
    io = pretty(io)
    print(terse(io), " over ", Lowercase(), base_ring(x))
  end
end

Base.show(io::IO, x::MatrixGroupElem) = show(io, matrix(x))
Base.show(io::IO, mi::MIME"text/plain", x::MatrixGroupElem) = show(io, mi, matrix(x))

group_element(G::MatrixGroup, x::GapObj) = MatrixGroupElem(G,x)

# Compute and store the component `G.X` if this is possible.
function assign_from_description(G::MatrixGroup)
   F = codomain(_ring_iso(G))
   GAP.Globals.IsBaseRingSupportedForClassicalMatrixGroup(F, GAP.GapObj(G.descr)) || error("no generators are known for the matrix group of type $(G.descr) over $(base_ring(G))")
   if G.descr==:GL G.X=GAP.Globals.GL(G.deg, F)
   elseif G.descr==:SL G.X=GAP.Globals.SL(G.deg, F)
   elseif G.descr==:Sp G.X=GAP.Globals.Sp(G.deg, F)
   elseif G.descr==Symbol("GO+") G.X=GAP.Globals.GO(1, G.deg, F)
   elseif G.descr==Symbol("SO+") G.X=GAP.Globals.SO(1, G.deg, F)
   elseif G.descr==Symbol("Omega+")
      # FIXME/TODO: Work around GAP issue <https://github.com/gap-system/gap/issues/500>
      # using the following inefficient code. In the future, we should use appropriate
      # generators for Omega (e.g. by applying a form change matrix to the Omega
      # generators returned by GAP).
      L = GAP.Globals.SubgroupsOfIndexTwo(GAP.Globals.SO(1, G.deg, F))
      if G.deg==4 && order(G.ring)==2  # this is the only case SO(n,q) has more than one subgroup of index 2
         for y in L
            _ranks = [GAP.Globals.Rank(u) for u in GAPWrap.GeneratorsOfGroup(y)]
            if all(r->iseven(r),_ranks)
               G.X=y
               break
            end
         end
      else
         @assert length(L) == 1
         G.X=L[1]
      end
   elseif G.descr==Symbol("GO-") G.X=GAP.Globals.GO(-1, G.deg, F)
   elseif G.descr==Symbol("SO-") G.X=GAP.Globals.SO(-1, G.deg, F)
   elseif G.descr==Symbol("Omega-") G.X=GAP.Globals.SubgroupsOfIndexTwo(GAP.Globals.SO(-1, G.deg, F))[1]
   elseif G.descr==:GO G.X=GAP.Globals.GO(0, G.deg, F)
   elseif G.descr==:SO G.X=GAP.Globals.SO(0, G.deg, F)
   elseif G.descr==:Omega
     # For even q or d = 1, \Omega(d,q) is equal to SO(d,q).
     # Otherwise, \Omega(d,q) has index 2 in SO(d,q).
     # Here d is odd, and we do not get here if d == 1 holds
     # because `omega_group` delegates to `SO` in this case.
     @assert G.deg > 1
     if iseven(GAPWrap.Size(F))
       G.X = GAP.Globals.SO(0, G.deg, F)
     else
       L = GAP.Globals.SubgroupsOfIndexTwo(GAP.Globals.SO(0, G.deg, F))
       @assert length(L) == 1
       G.X = L[1]
     end
   elseif G.descr==:GU G.X=GAP.Globals.GU(G.deg,Int(characteristic(G.ring)^(div(degree(G.ring),2) ) ))
   elseif G.descr==:SU G.X=GAP.Globals.SU(G.deg,Int(characteristic(G.ring)^(div(degree(G.ring),2) ) ))
   else error("unsupported description")
   end
end

function _ring_iso(G::MatrixGroup{T}) where T
  if !isdefined(G, :ring_iso)
    if T === QQBarFieldElem
      # get all matrix entries into one vector
      entries = reduce(vcat, vec(collect(matrix(g))) for g in gens(G))
      # construct a number field over which all matrices are already defined
      nf, nf_to_QQBar = number_field(QQ, entries)
      iso = iso_oscar_gap(nf)
      G.ring_iso = MapFromFunc(G.ring, codomain(iso),
                               x -> iso(preimage(nf_to_QQBar, x)),
                               y -> nf_to_QQBar(preimage(iso, y))
                               )
    else
      G.ring_iso = iso_oscar_gap(G.ring)
    end
  end
  return G.ring_iso
end

function GAP.julia_to_gap(G::MatrixGroup)
  if !isdefined(G, :X)
    if isdefined(G, :descr)
      assign_from_description(G)
    elseif isdefined(G, :gens)
      V = GapObj(gens(G); recursive=true)
      G.X = isempty(V) ? GAP.Globals.Group(V, GapObj(one(G))) : GAP.Globals.Group(V)
    else
      error("Cannot determine underlying GAP object")
    end
  end
  return G.X
end

function GAP.julia_to_gap(x::MatrixGroupElem)
  if !isdefined(x, :X)
    x.X = map_entries(_ring_iso(x.parent), x.elm)
  end
  return x.X
end

# return the G.sym if isdefined(G, :sym); otherwise, the field :sym is computed and set using information from other defined fields
function Base.getproperty(G::MatrixGroup{T}, sym::Symbol) where T

   isdefined(G,sym) && return getfield(G,sym)

   if sym === :X
      if isdefined(G,:descr)
         assign_from_description(G)
      elseif isdefined(G,:gens)
         V = GAP.GapObj([g.X for g in gens(G)])
         G.X = isempty(V) ? GAP.Globals.Group(V, one(G).X) : GAP.Globals.Group(V)
      else
         error("Cannot determine underlying GAP object")
      end
   end

   return getfield(G, sym)

end


function Base.getproperty(x::MatrixGroupElem, sym::Symbol)

   isdefined(x,sym) && return getfield(x,sym)

   if sym === :X
      x.X = map_entries(_ring_iso(x.parent), x.elm)
   end
   return getfield(x,sym)
end

Base.IteratorSize(::Type{<:MatrixGroup}) = Base.SizeUnknown()

Base.iterate(G::MatrixGroup) = iterate(G, GAPWrap.Iterator(GapObj(G)))

function Base.iterate(G::MatrixGroup, state::GapObj)
  GAPWrap.IsDoneIterator(state) && return nothing
  i = GAPWrap.NextIterator(state)::GapObj
  return MatrixGroupElem(G, i), state
end

########################################################################
#
# Membership
#
########################################################################


function ==(G::MatrixGroup,H::MatrixGroup)
   G.deg==H.deg || return false
   G.ring==H.ring || return false
   if isdefined(G, :descr) && isdefined(H, :descr)
      return G.descr == H.descr
   end
   if isdefined(G, :gens) && isdefined(H, :gens)
      gens(G)==gens(H) && return true
   end
   return GapObj(G)==GapObj(H)
end


# this saves the value of x.X
# x_gap = x.X if this is already known, x_gap = nothing otherwise
function lies_in(x::MatElem, G::MatrixGroup, x_gap)
   if base_ring(x)!=G.ring || nrows(x)!=G.deg return false, x_gap end
   if isone(x) return true, x_gap end
   if isdefined(G,:gens)
      for g in gens(G)
         if x==matrix(g)
            return true, x_gap
         end
      end
   end
   if isdefined(G,:descr) && G.descr === :GL
      return det(x)!=0, x_gap
   elseif isdefined(G,:descr) && G.descr === :SL
      return det(x)==1, x_gap
   elseif x_gap === nothing
      x_gap = map_entries(_ring_iso(G), x)
   end
   return (x_gap in GapObj(G)), x_gap
end

Base.in(x::MatElem, G::MatrixGroup) = lies_in(x,G,nothing)[1]

function Base.in(x::MatrixGroupElem, G::MatrixGroup)
   isdefined(x,:X) && return lies_in(matrix(x),G,GapObj(x))[1]
   _is_true, x_gap = lies_in(matrix(x),G,nothing)
   if x_gap !== nothing
      x.X = x_gap
   end
   return _is_true
end

# embedding an element of type MatElem into a group G
# if check=false, there are no checks on the condition `x in G`
function (G::MatrixGroup)(x::MatElem; check::Bool=true)
   if check
      _is_true, x_gap = lies_in(x,G,nothing)
      @req _is_true "Element not in the group"
      x_gap !== nothing && return MatrixGroupElem(G,x,x_gap)
   end
   return MatrixGroupElem(G,x)
end

# embedding an element of type MatrixGroupElem into a group G
# if check=false, there are no checks on the condition `x in G`
function (G::MatrixGroup)(x::MatrixGroupElem; check::Bool=true)
   if !check
      z = x
      z.parent = G
      return z
   end
   if isdefined(x,:X)
      if isdefined(x,:elm)
         _is_true = lies_in(matrix(x),G,GapObj(x))[1]
         @req _is_true "Element not in the group"
         return MatrixGroupElem(G,matrix(x),GapObj(x))
      else
         @req GapObj(x) in GapObj(G) "Element not in the group"
         return MatrixGroupElem(G,GapObj(x))
      end
   else
      _is_true, x_gap = lies_in(matrix(x),G,nothing)
      @req _is_true "Element not in the group"
      if x_gap === nothing
        return MatrixGroupElem(G,matrix(x))
      end
      return MatrixGroupElem(G,matrix(x),x_gap)
   end
end

# embedding a n x n array into a group G
function (G::MatrixGroup)(L::AbstractVecOrMat; check::Bool=true)
   x = matrix(G.ring, G.deg, G.deg, L)
   return G(x; check=check)
end


########################################################################
#
# Methods on elements
#
########################################################################

# we are not currently keeping track of the parent; two elements coincide iff their matrices coincide
function ==(x::MatrixGroupElem{S,T},y::MatrixGroupElem{S,T}) where {S,T}
   if isdefined(x,:X) && isdefined(y,:X) return x.X==y.X
   else return matrix(x)==matrix(y)
   end
end

function _common_parent_group(x::T, y::T) where T <: MatrixGroup
   @assert x.deg == y.deg
   @assert x.ring === y.ring
   x === y && return x
   return GL(x.deg, x.ring)::T
end

# Base.:* is defined in src/Groups/GAPGroups.jl, and it calls the function _prod below
# if the parents are different, the parent of the output product is set as GL(n,q)
function _prod(x::T,y::T) where {T <: MatrixGroupElem}
   G = _common_parent_group(parent(x), parent(y))

   # if the underlying GAP matrices are both defined, but not both Oscar matrices,
   # then use the GAP matrices.
   # Otherwise, use the Oscar matrices, which if necessary are implicitly computed
   # by the matrix(::MatrixGroupElem) method .
   if isdefined(x,:X) && isdefined(y,:X) && !(isdefined(x,:elm) && isdefined(y,:elm))
      return T(G, x.X*y.X)
   else
      return T(G, matrix(x)*matrix(y))
   end
end

Base.:*(x::MatrixGroupElem{RE, T}, y::T) where RE where T = matrix(x)*y
Base.:*(x::T, y::MatrixGroupElem{RE, T}) where RE where T = x*matrix(y)

Base.:^(x::MatrixGroupElem, n::Int) = MatrixGroupElem(x.parent, matrix(x)^n)

Base.isone(x::MatrixGroupElem) = isone(matrix(x))

Base.inv(x::MatrixGroupElem) = MatrixGroupElem(x.parent, inv(matrix(x)))

# if the parents are different, the parent of the output is set as GL(n,q)
function Base.:^(x::MatrixGroupElem, y::MatrixGroupElem)
   G = x.parent==y.parent ? x.parent : GL(x.parent.deg, x.parent.ring)
   if isdefined(x,:X) && isdefined(y,:X) && !(isdefined(x,:elm) && isdefined(y,:elm))
      return MatrixGroupElem(G, inv(y.X)*x.X*y.X)
   else
      return MatrixGroupElem(G,inv(matrix(y))*matrix(x)*matrix(y))
   end
end

comm(x::MatrixGroupElem, y::MatrixGroupElem) = inv(x)*conj(x,y)
#T why needed? GAPGroupElem has x^-1*x^y

"""
    det(x::MatrixGroupElem)

Return the determinant of the underlying matrix of `x`.
"""
det(x::MatrixGroupElem) = det(matrix(x))

"""
    base_ring(x::MatrixGroupElem)

Return the base ring of the underlying matrix of `x`.
"""
base_ring(x::MatrixGroupElem) = x.parent.ring

base_ring_type(::Type{<:MatrixGroupElem{RE}}) where {RE} = parent_type(RE)

parent(x::MatrixGroupElem) = x.parent

"""
    matrix(x::MatrixGroupElem)

Return the underlying matrix of `x`.
"""
function matrix(x::MatrixGroupElem)
  if !isdefined(x, :elm)
    x.elm = preimage_matrix(_ring_iso(x.parent), x.X)
  end
  return x.elm
end

Base.getindex(x::MatrixGroupElem, i::Int, j::Int) = matrix(x)[i,j]

"""
    number_of_rows(x::MatrixGroupElem)

Return the number of rows of the underlying matrix of `x`.
"""
number_of_rows(x::MatrixGroupElem) = number_of_rows(matrix(x))

"""
    number_of_columns(x::MatrixGroupElem)

Return the number of columns of the underlying matrix of `x`.
"""
number_of_columns(x::MatrixGroupElem) = number_of_columns(matrix(x))

#
size(x::MatrixGroupElem) = size(matrix(x))


"""
    tr(x::MatrixGroupElem)

Return the trace of the underlying matrix of `x`.
"""
tr(x::MatrixGroupElem) = tr(matrix(x))

#FIXME for the following functions, the output may not belong to the parent group of x
#=
frobenius(x::MatrixGroupElem, n::Int) = MatrixGroupElem(x.parent, matrix(x.parent.ring, x.parent.deg, x.parent.deg, [frobenius(y,n) for y in matrix(x)]))
frobenius(x::MatrixGroupElem) = frobenius(x,1)

transpose(x::MatrixGroupElem) = MatrixGroupElem(x.parent, transpose(matrix(x)))
=#

########################################################################
#
# Methods on groups
#
########################################################################

"""
    base_ring(G::MatrixGroup)

Return the base ring of the matrix group `G`.
"""
base_ring(G::MatrixGroup{RE}) where RE <: RingElem = G.ring::parent_type(RE)

base_ring_type(::Type{<:MatrixGroup{RE}}) where {RE} = parent_type(RE)

"""
    degree(G::MatrixGroup)

Return the degree of the matrix group `G`, i.e. the number of rows of its matrices.
"""
degree(G::MatrixGroup) = G.deg

Base.one(G::MatrixGroup) = MatrixGroupElem(G, identity_matrix(G.ring, G.deg))

function Base.rand(rng::Random.AbstractRNG, G::MatrixGroup)
   x_gap = GAP.Globals.Random(GAP.wrap_rng(rng), G.X)::GapObj
   return MatrixGroupElem(G, x_gap)
end

function gens(G::MatrixGroup)
   if !isdefined(G,:gens)
      L = GAPWrap.GeneratorsOfGroup(G.X)::GapObj
      G.gens = [MatrixGroupElem(G, a) for a in L]
   end
   return G.gens
end

# Note that the `gen(G::GAPGroup, i::Int)` method cannot be used
# for `MatrixGroup` because of the `:gens` attribute.
function gen(G::MatrixGroup, i::Int)
  i == 0 && return one(G)
  L = gens(G)
  0 < i && i <= length(L) && return L[i]
  i < 0 && -i <= length(L) && return inv(L[-i])
  @req false "i must be in the range -$(length(L)):$(length(L))"
end

number_of_generators(G::MatrixGroup) = length(gens(G))


compute_order(G::GAPGroup) = ZZRingElem(GAPWrap.Size(G.X))

function compute_order(G::MatrixGroup{T}) where {T <: Union{AbsSimpleNumFieldElem, QQFieldElem}}
  #=
    - For a matrix group G over the Rationals or over a number field,
    the GAP group G.X does usually not store the flag `IsHandledByNiceMonomorphism`.
    - If we know a reasonable ("nice") faithful permutation action of `G` in advance,
    we can set this flag in `G.X` to true and store the action homomorphism in `G.X`,
    and then this information should be used in the computation of the order.
    - If the flag is not known to be true then the Oscar code from
    `isomorphic_group_over_finite_field` shall be preferred.
  =#
  if GAP.Globals.HasIsHandledByNiceMonomorphism(G.X) && GAPWrap.IsHandledByNiceMonomorphism(G.X)
    # The call to `IsHandledByNiceMonomorphism` triggers an expensive
    # computation of `IsFinite` which we avoid by checking
    # `HasIsHandledByNiceMonomorphism` first.
    return ZZRingElem(GAPWrap.Size(G.X))
  else
    n = order(isomorphic_group_over_finite_field(G)[1])
    GAP.Globals.SetSize(G.X, GAP.Obj(n))
    return n
  end
end

function order(::Type{T}, G::MatrixGroup) where T <: IntegerUnion
   res = get_attribute!(G, :order) do
     return compute_order(G)
   end::ZZRingElem
   return T(res)::T
end

"""
    map_entries(f, G::MatrixGroup)

Return the matrix group obtained by applying `f` element-wise to
each generator of `G`.

`f` can be a ring or a field, a suitable map, or a Julia function.

# Examples
```jldoctest
julia> mat = matrix(ZZ, 2, 2, [1, 1, 0, 1]);

julia> G = matrix_group(mat);

julia> G2 = map_entries(x -> -x, G)
Matrix group of degree 2
  over integer ring

julia> is_finite(G2)
false

julia> order(map_entries(GF(3), G))
3
```
"""
function map_entries(f, G::MatrixGroup)
  Ggens = gens(G)
  if length(Ggens) == 0
    z = f(zero(base_ring(G)))
    return matrix_group(parent(z), degree(G), MatrixGroupElem[])
  else
    imgs = [map_entries(f, matrix(x)) for x in gens(G)]
    return matrix_group(imgs)
  end
end

function map_entries(R::Ring, G::MatrixGroup)
  imgs = [map_entries(R, matrix(x)) for x in gens(G)]
  return matrix_group(R, degree(G), imgs)
end

function map_entries(mp::Map, G::MatrixGroup)
  imgs = [map_entries(mp, matrix(x)) for x in gens(G)]
  return matrix_group(codomain(mp), degree(G), imgs)
end


########################################################################
#
# Constructors
#
########################################################################

function _field_from_q(q::Int)
   flag, n, p = is_prime_power_with_data(q)
   @req flag "The field size must be a prime power"

   return GF(p, n)
end

"""
    general_linear_group(n::Int, q::Int)
    general_linear_group(n::Int, R::Ring)
    GL = general_linear_group

Return the general linear group of dimension `n` over the ring `R` respectively the field `GF(q)`.

Currently `R` must be either a finite field or a residue ring or `ZZ`.

# Examples
```jldoctest
julia> F = GF(7)
Prime field of characteristic 7

julia> H = general_linear_group(2, F)
GL(2,7)

julia> gens(H)
2-element Vector{MatrixGroupElem{FqFieldElem, FqMatrix}}:
 [3 0; 0 1]
 [6 1; 6 0]

julia> order(general_linear_group(2, residue_ring(ZZ, 6)[1]))
288
```
"""
function general_linear_group(n::Int, R::Ring)
   G = matrix_group(R, n)
   G.descr = :GL
   return G
end

function general_linear_group(n::Int, q::Int)
   return general_linear_group(n, _field_from_q(q))
end

"""
    special_linear_group(n::Int, q::Int)
    special_linear_group(n::Int, R::Ring)
    SL = special_linear_group

Return the special linear group of dimension `n` over the ring `R` respectively the field `GF(q)`.

Currently `R` must be either a finite field or a residue ring or `ZZ`.

# Examples
```jldoctest
julia> F = GF(7)
Prime field of characteristic 7

julia> H = special_linear_group(2, F)
SL(2,7)

julia> gens(H)
2-element Vector{MatrixGroupElem{FqFieldElem, FqMatrix}}:
 [3 0; 0 5]
 [6 1; 6 0]

julia> order(special_linear_group(2, residue_ring(ZZ, 6)[1]))
144
```
"""
function special_linear_group(n::Int, R::Ring)
   G = matrix_group(R, n)
   G.descr = :SL
   return G
end

function special_linear_group(n::Int, q::Int)
   return special_linear_group(n, _field_from_q(q))
end

"""
    symplectic_group(n::Int, q::Int)
    symplectic_group(n::Int, R::Ring)
    Sp = symplectic_group

Return the symplectic group of dimension `n` over the ring `R` respectively the
field `GF(q)`. The dimension `n` must be even.

Currently `R` must be either a finite field
or a residue ring of prime power order.

# Examples
```jldoctest
julia> F = GF(7)
Prime field of characteristic 7

julia> H = symplectic_group(2, F)
Sp(2,7)

julia> gens(H)
2-element Vector{MatrixGroupElem{FqFieldElem, FqMatrix}}:
 [3 0; 0 5]
 [6 1; 6 0]

julia> order(symplectic_group(2, residue_ring(ZZ, 4)[1]))
48
```
"""
function symplectic_group(n::Int, R::Ring)
   @req iseven(n) "The dimension must be even"
   G = matrix_group(R, n)
   G.descr = :Sp
   return G
end

function symplectic_group(n::Int, q::Int)
   return symplectic_group(n, _field_from_q(q))
end

"""
    orthogonal_group(e::Int, n::Int, R::Ring)
    orthogonal_group(e::Int, n::Int, q::Int)
    GO = orthogonal_group

Return the orthogonal group of dimension `n` over the ring `R` respectively the
field `GF(q)`, and of type `e`, where `e` in {`+1`,`-1`} for `n` even and `e`=`0`
for `n` odd. If `n` is odd, `e` can be omitted.

Currently `R` must be either a finite field
or a residue ring of odd prime power order.

# Examples
```jldoctest
julia> F = GF(7)
Prime field of characteristic 7

julia> H = orthogonal_group(1, 2, F)
GO+(2,7)

julia> gens(H)
2-element Vector{MatrixGroupElem{FqFieldElem, FqMatrix}}:
 [3 0; 0 5]
 [0 1; 1 0]

julia> order(orthogonal_group(-1, 2, residue_ring(ZZ, 9)[1]))
24
```
"""
function orthogonal_group(e::Int, n::Int, R::Ring)
   if e==1
      @req iseven(n) "The dimension must be even"
      G = matrix_group(R, n)
      G.descr = Symbol("GO+")
   elseif e==-1
      @req iseven(n) "The dimension must be even"
      G = matrix_group(R, n)
      G.descr = Symbol("GO-")
   elseif e==0
      @req isodd(n) "The dimension must be odd"
      G = matrix_group(R, n)
      G.descr = :GO
   else
      throw(ArgumentError("Invalid description of orthogonal group"))
   end
   return G
end

function orthogonal_group(e::Int, n::Int, q::Int)
   return orthogonal_group(e, n, _field_from_q(q))
end

orthogonal_group(n::Int, R::Ring) = orthogonal_group(0,n,R)
orthogonal_group(n::Int, q::Int) = orthogonal_group(0,n,q)

"""
    special_orthogonal_group(e::Int, n::Int, R::Ring)
    special_orthogonal_group(e::Int, n::Int, q::Int)
    SO = special_orthogonal_group

Return the special orthogonal group of dimension `n` over the ring `R` respectively
the field `GF(q)`, and of type `e`, where `e` in {`+1`,`-1`} for `n` even and
`e`=`0` for `n` odd. If `n` is odd, `e` can be omitted.

Currently `R` must be either a finite field
or a residue ring of odd prime power order.

# Examples
```jldoctest
julia> F = GF(7)
Prime field of characteristic 7

julia> H = special_orthogonal_group(1, 2, F)
SO+(2,7)

julia> gens(H)
3-element Vector{MatrixGroupElem{FqFieldElem, FqMatrix}}:
 [3 0; 0 5]
 [5 0; 0 3]
 [1 0; 0 1]

julia> order(special_orthogonal_group(-1, 2, residue_ring(ZZ, 9)[1]))
12
```
"""
function special_orthogonal_group(e::Int, n::Int, R::Ring)
   characteristic(R) == 2 && return GO(e,n,R)
   if e==1
      @req iseven(n) "The dimension must be even"
      G = matrix_group(R, n)
      G.descr = Symbol("SO+")
   elseif e==-1
      @req iseven(n) "The dimension must be even"
      G = matrix_group(R, n)
      G.descr = Symbol("SO-")
   elseif e==0
      @req isodd(n) "The dimension must be odd"
      G = matrix_group(R, n)
      G.descr = :SO
   else
      throw(ArgumentError("Invalid description of orthogonal group"))
   end
   return G
end

function special_orthogonal_group(e::Int, n::Int, q::Int)
   return special_orthogonal_group(e, n, _field_from_q(q))
end

special_orthogonal_group(n::Int, R::Ring) = special_orthogonal_group(0,n,R)
special_orthogonal_group(n::Int, q::Int) = special_orthogonal_group(0,n,q)

"""
    omega_group(e::Int, n::Int, R::Ring)
    omega_group(e::Int, n::Int, q::Int)

Return the Omega group of dimension `n` over the field `GF(q)` of type `e`,
where `e` in {`+1`,`-1`} for `n` even and `e`=`0` for `n` odd. If `n` is odd,
`e` can be omitted.

Currently `R` must be either a finite field
or a residue ring of odd prime power order.

# Examples
```jldoctest
julia> F = GF(7)
Prime field of characteristic 7

julia> H = omega_group(1, 2, F)
Omega+(2,7)

julia> gens(H)
1-element Vector{MatrixGroupElem{FqFieldElem, FqMatrix}}:
 [2 0; 0 4]

julia> order(omega_group(0, 3, residue_ring(ZZ, 9)[1]))
324
```
"""
function omega_group(e::Int, n::Int, R::Ring)
   n==1 && return SO(e,n,R)
   if e==1
      @req iseven(n) "The dimension must be even"
      G = matrix_group(R, n)
      G.descr = Symbol("Omega+")
   elseif e==-1
      @req iseven(n) "The dimension must be even"
      G = matrix_group(R, n)
      G.descr = Symbol("Omega-")
   elseif e==0
      @req isodd(n) "The dimension must be odd"
      G = matrix_group(R, n)
      G.descr = :Omega
   else
      throw(ArgumentError("Invalid description of orthogonal group"))
   end
   return G
end

function omega_group(e::Int, n::Int, q::Int)
   return omega_group(e, n, _field_from_q(q))
end

omega_group(n::Int, q::Int) = omega_group(0,n,q)
omega_group(n::Int, R::Ring) = omega_group(0,n,R)

"""
    unitary_group(n::Int, q::Int)
    GU = unitary_group

Return the unitary group of dimension `n` over the field `GF(q^2)`.

# Examples
```jldoctest
julia> H = unitary_group(2,3)
GU(2,3)

julia> gens(H)
2-element Vector{MatrixGroupElem{FqFieldElem, FqMatrix}}:
 [o 0; 0 2*o]
 [2 2*o+2; 2*o+2 0]
```
"""
function unitary_group(n::Int, q::Int)
   fl, a, b = is_prime_power_with_data(q)
   @req fl "The field size must be a prime power"
   G = matrix_group(GF(b, 2*a), n)
   G.descr = :GU
   return G
end

"""
    special_unitary_group(n::Int, q::Int)
    SU = special_unitary_group

Return the special unitary group of dimension `n` over the field with `q^2`
elements.

# Examples
```jldoctest
julia> H = special_unitary_group(2,3)
SU(2,3)

julia> gens(H)
2-element Vector{MatrixGroupElem{FqFieldElem, FqMatrix}}:
 [1 2*o+2; 0 1]
 [0 2*o+2; 2*o+2 0]
```
"""
function special_unitary_group(n::Int, q::Int)
   fl, a, b = is_prime_power_with_data(q)
   @req fl "The field size must be a prime power"
   G = matrix_group(GF(b, 2*a), n)
   G.descr = :SU
   return G
end

const GL = general_linear_group
const SL = special_linear_group
const Sp = symplectic_group
const GO = orthogonal_group
const SO = special_orthogonal_group
const GU = unitary_group
const SU = special_unitary_group

########################################################################
#
# Subgroups
#
########################################################################

function sub(G::MatrixGroup, elements::Vector{S}) where S <: GAPGroupElem
   @assert elem_type(G) === S
   elems_in_GAP = GAP.Obj(GapObj[x.X for x in elements])
   H = GAP.Globals.Subgroup(G.X,elems_in_GAP)::GapObj
   #H is the group. I need to return the inclusion map too
   K,f = _as_subgroup(G, H)
   L = Vector{elem_type(K)}(undef, length(elements))
   for i in 1:length(L)
      L[i] = MatrixGroupElem(K, matrix(elements[i]), elements[i].X)
   end
   K.gens = L
   return K,f
end


########################################################################
#
# Conjugation
#
########################################################################

function Base.show(io::IO, x::GroupConjClass{T,S}) where T <: MatrixGroup where S <: MatrixGroupElem
  show(io, x.repr)
  print(io, " ^ ")
  show(io, x.X)
end

function Base.show(io::IO, x::GroupConjClass{T,S}) where T <: MatrixGroup where S <: MatrixGroup
  show(io, x.repr)
  print(io, " ^ ")
  show(io, x.X)
end

function Base.:^(H::MatrixGroup, y::MatrixGroupElem)
   if isdefined(H,:gens) && !isdefined(H,:X)
      K = matrix_group(base_ring(H), degree(H))
      K.gens = [y^-1*x*y for x in H.gens]
      for k in gens(K) k.parent = K end
   else
      K = matrix_group(base_ring(H), degree(H))
      K.X = H.X^y.X
   end

   return K
end

function Base.rand(rng::Random.AbstractRNG, C::GroupConjClass{S,T}) where S<:MatrixGroup where T<:MatrixGroup
   H = matrix_group(C.X.ring, C.X.deg)
   H.X = GAP.Globals.Random(GAP.wrap_rng(rng), C.CC)::GapObj
   return H
end

function Base.rand(C::GroupConjClass{S,T}) where S<:MatrixGroup where T<:MatrixGroup
   return Base.rand(Random.GLOBAL_RNG, C)
end
