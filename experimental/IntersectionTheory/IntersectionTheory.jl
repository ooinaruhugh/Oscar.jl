module IntersectionTheory
using Oscar
using Markdown

import Base: +, -, *, ^, ==, div, zero, one, parent
import Oscar: AlgHom, Ring, Ring_dec, RingElem_dec
import Oscar: basis, chi, codomain, degree, det, dim, domain, dual, gens, hilbert_polynomial, hom, integral, rank, signature, total_degree
import AbstractAlgebra: combinations, @declare_other, get_special, set_special
import AbstractAlgebra.Generic: FunctionalMap, Partition, partitions

export betti, chern, ctop, euler, graph, todd, OO
export a_hat_genus, l_genus, pontryagin, chern_number, chern_numbers
export intersection_matrix, dual_basis
export pullback, pushforward
export bundles, tangent_bundle, cotangent_bundle, canonical_bundle, canonical_class
export symmetric_power, exterior_power, schur_functor
export →
export complete_intersection, section_zero_locus, degeneracy_locus
export proj, grassmannian, flag, point, variety, bundle
export schubert_class, schubert_classes

include("Types.jl")
include("Misc.jl")

include("Bott.jl")   # integration using Bott's formula
include("Main.jl")   # basic constructions for Schubert calculus
# include("Blowup.jl") # blowup
# include("Moduli.jl") # moduli of matrices, twisted cubics
# include("Weyl.jl")   # weyl groups

end # module
using .IntersectionTheory
