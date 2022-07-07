@enum StackData::UInt8 begin
	st_interpolation # $(
	st_quot_1 # '
	st_quot_2 # "
	st_quot_sq # `
	st_q3_1 # '''
	st_q3_2 # """
	st_comment # 多行注释
	st_bra_s # (
	st_bra_m # [
	st_bra_l # {
end
abstract type CommonHighlightRule end

"""
`userule(r::CommonHighlightRule, str::AbstractString, i::Int, stack, meta) -> Union{Tuple{Int, Pair}, Nothing}`

`nothing` will be return if the rule isn't successfully excuted\\
the integer shows where the next reading index shall be
"""
function userule end

struct EmptyRule end
userule(::EmptyRule, ::AbstractString, ::Int, stack, meta)= str=="" ? (1, :plain => "") : nothing

struct SelfDefRule f::Function end
userule(r::EmptyRule, str::AbstractString, i::Int, stack, meta)= r.f(str, i, stack, meta)

"""
This rule is used to recognize patterns at the start of a line.
- `pattern::Union{AbstractString, Regex}`
- `patlength::Int = 0` for strings, this should usually be set to `sizeof(pattern)`, and for regex, this means the last index of found pattern must not be less than `patlength`
- `offset::Integer = 0` set the offset after pattern found
- `hl_type::Symbol = :shell`
- `record::Bool = false` whether to record for `RecordedLineStartRule`
"""
Base.@kwdef struct LineStartRule <: CommonHighlightRule
	pattern::Union{AbstractString, Regex}
	patlength::Int = 0
	offset::Integer = 0
	hl_type::Symbol = :shell
	record::Bool = false
end
function userule(r::LineStartRule, str::AbstractString, ::Int, stack, meta)
	if i!=1
		return nothing
	end
	if isa(r.pattern, Regex)
		f=findfirst(r.pattern, str)
		if f===nothing
			return nothing
		end
		if f.stop<patlength
			return nothing
		end
		res=str[1:f.stop+r.offset]
		if r.record
			meta[:record_linestart]=res
		end
		return (f.stop+r.offset+1, r.hl_type => res)
	else
		if startswith(str, r.pattern)
			res=str[1:r.patlength+r.offset]
			if r.record
				meta[:record_linestart]=res
			end
			return (r.patlength+offset+1, r.hl_type => res)
		else
			return nothing
		end
	end
end

"""
This rule checks `meta[:record_linestart]`
"""
struct RecordedLineStartRule <: CommonHighlightRule end
function userule(::RecordedLineStartRule, str::AbstractString, ::Int, stack, meta)
	if i!=1
		return nothing
	end
	record=meta[:record_linestart]
	if startswith(str, record)
		return (sizeof(str)+1, :shell => record)
	else
		return nothing
	end
end

struct PlainAllRule <: CommonHighlightRule end
function userule(::RecordedLineStartRule, str::AbstractString, i::Int, stack, meta)
	return (sizeof(str)+1, :plain => str[i:end])
end

struct IDRule
	id_start_char::Function
	id_char::Function
	specialize::Vector{<:Function}
end
function userule(r::IDRule, str::AbstractString, i::Int, stack, meta)
	ch=str[i]
	if !r.id_start_char(ch)
		return nothing
	end
	over=sizeof(str)+1
	j=nextind(sz, i)
	while j<over
		ch=@inbounds str[i]
		if !r.id_char(ch)
			break
		end
		j=nextind(str, j)
	end
	to=prevind(str, j)
	for func in r.specialize
		res=func(str, i, to, stack, meta)
		if res!==nothing
			return (j, res)
		end
	end
	return (j, :plain => str[i:to])
end
