## Poly{T} is basically T[x], with T a Ring.
## T[x] may not have an order so abs, comparing to 0 may not be defined.

## to handle this case we create some functions
## which can be modified by users for other Ts

"`hasneg(::T)` attribute is true if: `pj < zero(T)` is defined."
hasneg(::Type{T}) where {T} = false

"Could value possibly be negative and if so, is it?"
isneg(pj::T) where {T} = hasneg(T) && pj < zero(T)

"Make `pj` positive if it is negative. (Don't call `abs` as that may not be defined, or appropriate.)"
aspos(pj::T) where {T} = (hasneg(T) && isneg(pj)) ? -pj : pj

"Should a value of `one(T)` be shown as a coefficient of monomial `x^i`, `i >= 1`? (`1.0x^2` is shown, `1 x^2` is not)"
showone(::Type{T}) where {T} = true


#####

## Numbers
hasneg(::Type{T}) where {T<:Real} = true

### Integer
showone(::Type{T}) where {T<:Integer} = false
showone(::Type{Rational{T}}) where {T<:Integer} = false




### Complex coefficients
hasneg(::Type{Complex{T}}) where {T} = true      ## we say neg if real(z) < 0 || real(z) == 0 and imag(g) < 0

function isneg(pj::Complex{T}) where {T}
    real(pj) < 0 && return true
    (real(pj) == 0 && imag(pj) < 0) && return(true)
    return false
end

showone(pj::Type{Complex{T}}) where {T} = showone(T)


### Polynomials as coefficients
hasneg(::Type{Poly{S}}) where {S} = false
showone(::Type{Poly{S}}) where {S} = false


### show parentheses?
"""
    needsparens(pj::T, j::Int)

Add parentheses to coefficient `pj * x^j of type `T` when printing.
Can be overridden by external types to control printing.
"""
function needsparens(pj::Complex{T}, j) where {T}
    hasreal = abs(real(pj)) > 0 || isnan(real(pj)) || isinf(real(pj))
    hasimag = abs(imag(pj)) > 0 || isnan(imag(pj)) || isinf(imag(pj))
    hasreal && hasimag  && return true
    false
end

# catchall
# PR #147, a good idea?
# needsparens(pj, j) = occursin(" + ", string(pj)) || contains(" - ", string(pj))
needsparens(pj, j) = false


#####

"Show different operations depending on mimetype. `l-` is leading minus sign."
function showop(::MIME"text/plain", op)
    d = Dict("*" => "*", "+" => " + ", "-" => " - ", "l-" => "-")
    d[op]
end

function showop(::MIME"text/latex", op)
    d = Dict("*" => "\\cdot ", "+" => " + ", "-" => " - ", "l-" => "-")
    d[op]
end

function showop(::MIME"text/html", op)
    d = Dict("*" => "&#8729;", "+" => " &#43; ", "-" => " &#45; ", "l-" => "&#45;")
    d[op]
end



###

"""
    printpoly(io::IO, p::Poly, mimetype = MIME"text/plain"(); descending_powers=false)

Print a human-readable representation of the polynomial `p` to `io`. The MIME
types "text/plain" (default), "text/latex", and "text/html" are supported. By
default, the terms are in order of ascending powers, matching the order in
`coeffs(p)`; specifying `descending_powers=true` reverses the order.

# Examples
```jldoctest
julia> printpoly(stdout, Poly([1,2,3], :y))
1 + 2*y + 3*y^2
julia> printpoly(stdout, Poly([1,2,3], :y), descending_powers=true)
3*y^2 + 2*y + 1
```
"""
function printpoly(io::IO, p::Poly{T}, mimetype = MIME"text/plain"(); descending_powers=false) where {T}
    first = true
    printed_anything = false
    for i in (descending_powers ? reverse(eachindex(p)) : eachindex(p))
        printed = showterm(io,p,i,first, mimetype)
        first &= !printed
        printed_anything |= printed
    end
    printed_anything || print(io, zero(T))
    return nothing
end

function showterm(io::IO,p::Poly{T},j,first, mimetype) where {T}
    pj = p[j]

    pj == zero(T) && return false

    pj = printsign(io, pj, j, first, mimetype)
    printcoefficient(io, pj, j, mimetype)
    printproductsign(io, pj, j, mimetype)
    printexponent(io,p.var,j, mimetype)
    true
end



## print the sign
## returns aspos(pj)
function printsign(io::IO, pj::T, j, first, mimetype) where {T}
    neg = isneg(pj)
    if first
        neg && print(io, showop(mimetype, "l-"))    #Prepend - if first and negative
    else
        neg ? print(io, showop(mimetype, "-")) : print(io,showop(mimetype, "+"))
    end

    aspos(pj)
end

## print * or cdot, ...
function printproductsign(io::IO, pj::T, j, mimetype) where {T}
    j == 0 && return
    (showone(T) || pj != one(T)) &&  print(io, showop(mimetype, "*"))
end

# show a single term
function printcoefficient(io::IO, pj::Complex{T}, j, mimetype) where {T}

    hasreal = abs(real(pj)) > 0 || isnan(real(pj)) || isinf(real(pj))
    hasimag = abs(imag(pj)) > 0 || isnan(imag(pj)) || isinf(imag(pj))

    if needsparens(pj, j)
        print(io, '(')
        _show(io, mimetype, pj)
        print(io, ')')
    elseif hasreal
        a = real(pj)
        (j==0 || showone(T) || a != one(T)) && _show(io, mimetype, a)
    elseif hasimag
        b = imag(pj)
        (showone(T) || b != one(T)) && _show(io,  mimetype, b)
        (isnan(imag(pj)) || isinf(imag(pj))) && print(io, showop(mimetype, "*"))
        _show(io, mimetype, im)
    else
        return
    end
end


## show a single term
function printcoefficient(io::IO, pj::T, j, mimetype) where {T}
    pj == one(T) && !(showone(T) || j == 0) && return
    if needsparens(pj, j)
        print(io, '('); _show(io, mimetype, pj); print(io, ')')
    else
        _show(io, mimetype, pj)
    end
end

## show exponent
function printexponent(io,var,i, mimetype::MIME"text/latex")
    if i == 0
        return
    elseif i == 1
        print(io,var)
    else
        print(io,var,"^{$i}")
    end
end

function printexponent(io,var,i, mimetype)
    if i == 0
        return
    elseif i == 1
        print(io,var)
    else
        print(io,var,"^",i)
    end
end


####

## text/plain
Base.show(io::IO, p::Poly{T}) where {T} = show(io, MIME("text/plain"), p)

function Base.show(io::IO, mimetype::MIME"text/plain", p::Poly{T}) where {T}
    print(io,"Poly(")
    printpoly(io, p, mimetype)
    print(io,")")

end

## text/latex
function Base.show(io::IO, mimetype::MIME"text/latex", p::Poly{T}) where {T}
    print(io, "\$")
    printpoly(io, p, mimetype)
    print(io, "\$")
end


## text/html
function Base.show(io::IO, mimetype::MIME"text/html", p::Poly{T}) where {T}
    printpoly(io, p, mimetype)
end


## intercept show to allow prettier printing of rationals

function _show(io::IO, mimetype::MIME"text/latex", a::Rational{T}) where {T}
    abs(a.den) == one(T) ? print(io, a.num) : print(io, "\\frac{$(a.num)}{$(a.den)}")
end

_show(io::IO, M, a::Any) = print(io,a)
