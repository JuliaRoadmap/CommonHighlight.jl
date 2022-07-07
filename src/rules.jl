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
function closeprev(vec, str::AbstractString, from::Int, over::Int, status)
	to=prevind(str, over)
	chunk=str[from:to]
	if chunk!=""
		if status.weakemp
			push!(vec, :plain => str)
		else
			push!(vec, :string => str)
		end
		status[:prev]=over
	end
end

abstract type CommonHighlightRule end

"""
`userule(r::CommonHighlightRule, vec, str::AbstractString, i::Int, status) -> Int`
"""
function userule::Int end

struct EmptyRule end
function userule(::EmptyRule, vec, str::AbstractString, ::Int, status)
	if str==""
		return 0
	else
		push!(vec, :plain => "")
		return 1
	end
end

struct SelfDefRule f::Function end
userule(r::EmptyRule, vec, str::AbstractString, i::Int, status)= r.f(str, vec, str, i, status)

struct JumpSpaceRule end
function userule(::JumpSpaceRule, vec, str::AbstractString, i::Int, status)
	over=sizeof(str)+1
	while i<over && (str[i]==' ' || str[i]=='\t')
		i+=1
	end
	return i
end

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
function userule(r::LineStartRule, vec, str::AbstractString, i::Int, status)
	if i!=1
		return 0
	end
	if isa(r.pattern, Regex)
		f=findfirst(r.pattern, str)
		if f===nothing || f.stop<patlength
			return 0
		end
		res=str[1:f.stop+r.offset]
		if r.record
			status[:record_linestart]=res
		end
		push!(vec, r.hl_type => res)
		return f.stop+r.offset+1
	else
		if startswith(str, r.pattern)
			res=str[1:r.patlength+r.offset]
			if r.record
				meta[:record_linestart]=res
			end
			push!(vec, r.hl_type => res)
			return r.patlength+offset+1
		else
			return 0
		end
	end
end

"""
This rule checks `meta[:record_linestart]`
"""
struct RecordedLineStartRule <: CommonHighlightRule end
function userule(::RecordedLineStartRule, vec, str::AbstractString, i::Int, status)
	if i!=1
		return 0
	end
	record=status[:record_linestart]
	if startswith(str, record)
		push!(vec, :shell => record)
		return sizeof(str)+1
	else
		return 0
	end
end

struct PlainAllRule <: CommonHighlightRule end
function userule(::RecordedLineStartRule, vec, str::AbstractString, i::Int, status)
	push!(vec, :plain => str[status[:prev]:end])
	return sizeof(str)+1
end

struct IDRule
	id_start_char::Function
	id_char::Function
	specialize::Function
end
function userule(r::IDRule, vec, str::AbstractString, i::Int, status)
	ch=str[i]
	if !r.id_start_char(ch)
		return 0
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
	chunk=str[i:to]
	res=r.specialize(str, i, to, chunk, status)
	if res!=0
		return j
	end
	return j
end
