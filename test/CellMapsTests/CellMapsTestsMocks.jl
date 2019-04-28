import Numa.CellValues: cellsize
using Numa.CellValues: IndexCellArray

import Base: IndexStyle, size, getindex

struct CellArrayMockup{T,N} <: IndexCellArray{T,N,Array{T,N},1}
  a::Array{T,N}
  l::Int
end

function getindex(self::CellArrayMockup,cell::Vararg{Int,N} where N)
  @assert 1 <= cell
  @assert cell <= length(self)
  self.a
end

size(self::CellArrayMockup) = (self.l,)

IndexStyle(::Type{CellArrayMockup{T,N}} where {T,N}) = IndexLinear()

cellsize(self::CellArrayMockup) = size(self.a)

const CellFieldValuesMockup{T} = CellArrayMockup{T,1} where T <:FieldValue
const CellBasisValuesMockup{T} = CellArrayMockup{T,2} where T <:FieldValue

sfva = [1.0,2.3,3.1,3.2]
sbva = [sfva'; sfva'; sfva']
sfv = CellFieldValuesMockup{Float64}(sfva,l)
sfv2 = CellFieldValuesMockup{Float64}(sfva[1:3],l)
sbv = CellBasisValuesMockup{Float64}(sbva,l)


vv = VectorValue(2.0,2.1)
vfva = [vv,2*vv,-1*vv,0.3*vv]
vbva = Array{VectorValue{2},2}(undef,(3,4))
for j in 1:4
  for i in 1:3
    vbva[i,j] = (i*j)*vv
  end
end
vfv = CellFieldValuesMockup{VectorValue{2}}(vfva,l)
vfv2 = CellFieldValuesMockup{VectorValue{2}}(vfva[1:3],l)
vbv = CellBasisValuesMockup{VectorValue{2}}(vbva,l)

tv = TensorValue(2.0,2.1,3.4,4.1)
tfva = [tv,2*tv,-1*tv,0.3*tv]
tbva = Array{TensorValue{2,4},2}(undef,(3,4))
for j in 1:4
  for i in 1:3
    tbva[i,j] = (i*j)*tv
  end
end
tfv = CellFieldValuesMockup{TensorValue{2,4}}(tfva,l)
tbv = CellBasisValuesMockup{TensorValue{2,4}}(tbva,l)

import Numa: evaluate
using Numa.CellMaps: IterCellField, IterCellBasis

struct ScalarFieldMock <: IterCellField{2,Float64} end

evaluate(::ScalarFieldMock,points::CellPoints{2}) = sfv

struct ScalarBasisMock <: IterCellBasis{2,Float64} end

evaluate(::ScalarBasisMock,points::CellPoints{2}) = sbv
