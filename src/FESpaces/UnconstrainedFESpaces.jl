
"""
Generic implementation of an unconstrained single-field FE space
Private fields and type parameters
"""
struct UnconstrainedFESpace{V} <: SingleFieldFESpace
  vector_type::Type{V}
  nfree::Int
  ndirichlet::Int
  cell_dofs_ids::AbstractArray
  cell_shapefuns::CellField
  cell_dof_basis::CellDof
  cell_is_dirichlet::AbstractArray{Bool}
  dirichlet_dof_tag::Vector{Int8}
  dirichlet_cells::Vector{Int32}
  ntags::Int
end

# FESpace interface

ConstraintStyle(::Type{<:UnconstrainedFESpace}) = UnConstrained()
get_free_dof_ids(f::UnconstrainedFESpace) = Base.OneTo(f.nfree)
zero_free_values(f::UnconstrainedFESpace) = allocate_vector(f.vector_type,num_free_dofs(f))
get_cell_shapefuns(f::UnconstrainedFESpace) = f.cell_shapefuns
get_cell_dof_basis(f::UnconstrainedFESpace) = f.cell_dof_basis
get_cell_dof_ids(f::UnconstrainedFESpace) = f.cell_dofs_ids
get_triangulation(f::UnconstrainedFESpace) = get_triangulation(f.cell_shapefuns)
get_dof_value_type(f::UnconstrainedFESpace{V}) where V = eltype(V)
get_vector_type(f::UnconstrainedFESpace{V}) where V = V
get_cell_is_dirichlet(f::UnconstrainedFESpace) = f.cell_is_dirichlet

# SingleFieldFESpace interface

get_dirichlet_dof_ids(f::UnconstrainedFESpace) = Base.OneTo(f.ndirichlet)
num_dirichlet_tags(f::UnconstrainedFESpace) = f.ntags
zero_dirichlet_values(f::UnconstrainedFESpace) = allocate_vector(f.vector_type,num_dirichlet_dofs(f))
get_dirichlet_dof_tag(f::UnconstrainedFESpace) = f.dirichlet_dof_tag

function scatter_free_and_dirichlet_values(f::UnconstrainedFESpace,free_values,dirichlet_values)
  @check eltype(free_values) == eltype(dirichlet_values) """\n
  The entries stored in free_values and dirichlet_values should be of the same type.

  This error shows up e.g. when trying to build a FEFunction from a vector of integers
  if the Dirichlet values of the underlying space are of type Float64, or when the
  given free values are Float64 and the Dirichlet values ComplexF64.
  """
  cell_dof_ids = get_cell_dof_ids(f)
  cell_reffes=_get_cell_reffes(f)
  phys_cell_info=_get_dof_basis_physical_cell_info(f)

  cell_global_dofs=lazy_map(Broadcasting(PosNegReindex(free_values,dirichlet_values)),cell_dof_ids)
  lazy_map(get_cell_local_dofs_from_global_dofs,
           cell_reffes,
           cell_global_dofs,
           phys_cell_info)
end

function gather_free_and_dirichlet_values!(free_vals,dirichlet_vals,f::UnconstrainedFESpace,cell_vals)

  cell_dofs = get_cell_dof_ids(f)
  cache_vals = array_cache(cell_vals)
  cache_dofs = array_cache(cell_dofs)
  cells = 1:length(cell_vals)

  _free_and_dirichlet_values_fill!(
    free_vals,
    dirichlet_vals,
    cache_vals,
    cache_dofs,
    cell_vals,
    cell_dofs,
    cells)

  (free_vals,dirichlet_vals)
end

function gather_dirichlet_values!(dirichlet_vals,f::UnconstrainedFESpace,cell_vals)

  cell_dofs = get_cell_dof_ids(f)
  cache_vals = array_cache(cell_vals)
  cache_dofs = array_cache(cell_dofs)
  free_vals = zero_free_values(f)
  cells = f.dirichlet_cells

  _free_and_dirichlet_values_fill!(
    free_vals,
    dirichlet_vals,
    cache_vals,
    cache_dofs,
    cell_vals,
    cell_dofs,
    cells)

  dirichlet_vals
end

function  _free_and_dirichlet_values_fill!(
  free_vals,
  dirichlet_vals,
  cache_vals,
  cache_dofs,
  cell_vals,
  cell_dofs,
  cells)

  for cell in cells
    vals = getindex!(cache_vals,cell_vals,cell)
    dofs = getindex!(cache_dofs,cell_dofs,cell)
    for (i,dof) in enumerate(dofs)
      val = vals[i]
      if dof > 0
        free_vals[dof] = val
      elseif dof < 0
        dirichlet_vals[-dof] = val
      else
        @unreachable "dof ids either positive or negative, not zero"
      end
    end
  end

end

# TEMPORARY PRIVATE FUNCTION
function _get_cell_reffes(f::UnconstrainedFESpace)
  get_data(f.cell_dof_basis).args[1]
end

# TEMPORARY PRIVATE FUNCTION
function _get_dof_basis_physical_cell_info(f::UnconstrainedFESpace)
  get_data(f.cell_dof_basis).args[3]
end

# TEMPORARY PRIVATE FUNCTION
function _get_model(f::UnconstrainedFESpace)
  get_data(f.cell_dof_basis).args[3].maps[1].model
end

function get_cell_local_dofs_from_global_dofs(reffe,
  cell_global_dofs::AbstractVector,
  cell_is_slave::AbstractVector{Bool})

  cache = return_cache(get_cell_local_dofs_from_global_dofs,
                       cell_global_dofs,
                       cell_is_slave)
  evaluate!(cache,
            get_cell_local_dofs_from_global_dofs,
            cell_global_dofs,
            cell_is_slave)
end

function evaluate!(cache,
  ::typeof(get_cell_local_dofs_from_global_dofs),
  reffe::ReferenceFE,
  cell_global_dofs::AbstractVector,
  cell_is_slave::AbstractVector{Bool})
  cell_global_dofs
end

function return_cache(::typeof(get_cell_local_dofs_from_global_dofs),
                      reffe::GenericRefFE{RaviartThomas},
                      cell_global_dofs::AbstractVector,
                      cell_is_slave::AbstractVector{Bool})
    CachedVector(eltype(cell_global_dofs))
end

function evaluate!(cache,
                   ::typeof(get_cell_local_dofs_from_global_dofs),
                   reffe::GenericRefFE{RaviartThomas},
                   cell_global_dofs::AbstractVector,
                   cell_is_slave::AbstractVector{Bool})

  cell_local_dofs=cache
  setsize!(cell_local_dofs,(num_dofs(reffe),))
  cell_local_dofs .= cell_global_dofs

  D=num_dims(reffe)
  current=get_offsets(get_polytope(reffe))[D]+1
  face_own_dofs=get_face_own_dofs(reffe)
  for i=1:num_facets(get_polytope(reffe))
     if cell_is_slave[current]
        for dof in face_own_dofs[current]
           cell_local_dofs[dof]=-cell_local_dofs[dof]
        end
     end
     current=current+1
  end
  cell_local_dofs
end
