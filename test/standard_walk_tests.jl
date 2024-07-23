
@testset "StandardWalk" begin
    
R1, (x,y,z) = polynomial_ring(QQ, ["x", "y", "z"])
    
I1 = ideal([x^2 + y*z, x*y + z^2]) 
    
G1 = groebner_basis(I1)

@test bounding_vectors(G1) == ZZ.([[1,1,-2],[2,-1,-1], [-1,2,-1])
@test next_weight(G1, ZZ.([1,1,1]), ZZ.([1,0,0])) == ZZ.([1,1,1])


I2 = ideal([z^3 - z^2 - 4])
G2 = groebner_basis(I2)

@test bounding_vectors(G2) == ZZ.([[0,0,1],[0,0,3]])


I3 = ideal([x^6 - 1])
G3 = groebner_basis(I3)
@test bounding_vectors(G3) == ZZ.([[6,0,0]])
@test next_weight(G3, ZZ.([1,1,1]), ZZ.([1,0,0])) == ZZ.([1,0,0])




end 
