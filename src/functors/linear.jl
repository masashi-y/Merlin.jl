type Linear <: Functor
  w::Variable
  b::Variable
end

function Linear{T}(::Type{T}, xlength::Int, ylength::Int)
  r = randn(ylength, xlength) * sqrt(1 / xlength)
  w = convert(Array{T}, r)
  b = fill(T(0.01), ylength)
  w = Variable(w, zeros(w))
  b = Variable(b, zeros(b))
  Linear(w, b)
end

function Linear{T}(::AFArray{T}, xlength::Int, ylength::Int)
  r = randn(AFArray{T}, ylength, xlength) * sqrt(1 / xlength)
  w = convert(AFArray{T}, r)
  b = fill(T(0.01), ylength)
  w = Variable(w, zeros(w))
  b = Variable(b, zeros(b))
  Linear(w, b)
end

mat(a::Array) = reshape(a, size(a, 1), length(a)÷size(a,1))
isvec(a::Array) = ndims(a) == 2 && size(a, 2) == 1

function forward!(f::Linear, v::Variable)
  v.value = linear(f.w.value, f.b.value, v[1].value)
end

function linear{T}(w::Matrix{T}, b::Vector{T}, x::Matrix{T})
  y = alloc_cpu(T, size(w,1), size(x,2))
  gemm!('N', 'N', T(1), w, x, T(0), y)
  broadcast!(+, y, b, y)
  y
end

function linear{T}(w::AFMatrix{T}, b::AFVector{T}, x::AFMatrix{T})
  w * x
  # broadcast!(+, y, b, y)
  y
end

function backward!(f::Linear, v::Variable)
  ∇linear_dwb!(f.w.grad, f.b.grad, v[1].value, v.grad)
  gx = ∇linear_dx(f.w.value, v[1].value, v.grad)
  addgrad!(v[1], gx)
end

"""
d_y / d_x = w^T * gy
d_y / d_w = gy * x^T
d_y / d_b = 1
"""
function ∇linear_dx{T}(w::Matrix{T}, x::Matrix{T}, gy::Matrix{T})
  gx = alloc_cpu(T, size(x))
  gemm!('T', 'N', T(1), w, gy, T(0), gx)
  gx
end

function ∇linear_dwb!{T}(gw::Matrix{T}, gb::Vector{T}, x::Matrix{T}, gy::Matrix{T})
  gemm!('N', 'T', T(1), gy, x, T(1), gw)
  sum!(gb, gy)
end

function optimize!(opt::Optimizer, f::Linear)
  update!(opt, f.w.value, f.w.grad)
  update!(opt, f.b.value, f.b.grad)
end
