module CellQuadraturesTests

using Test
using Numa.FieldValues
using Numa.Quadratures
using Numa.CellValues
using Numa.CellQuadratures

const D = 2

p = Point{D}(1.0,1.1)

c = [ i*p for i in 1:4 ]

w = [ i*1.0 for i in 1:4 ]

l = 10

quad = ConstantCellQuadrature(c,w,l)

q = coordinates(quad)
qw = weights(quad)

@test isa(q,CellVector{Point{D}})

@test isa(qw,CellVector{Float64})

# We can iterate coordinates and weights separately

for iq in q
  @test iq == c
end

for iw in qw
  @test iw == w
end

# or simultaneously

for (iq,iw) in zip(quad)
  @test iq == c
  @test iw == w
end

ref_quad = TensorProductQuadrature(orders=(5,4))
quad2 = ConstantCellQuadrature(ref_quad,l)

@test isa(quad2,CellQuadrature)

end # module CellQuadraturesTests
