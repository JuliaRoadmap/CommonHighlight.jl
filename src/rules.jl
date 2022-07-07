@enum StackData::UInt8 begin
	st_interpolation # $(
	st_quot_1 # '
	st_quot_2 # "
	st_quot_sq # `
	st_q3_1 # '''
	st_q3_2 # """
	st_comment # 多行注释
end
abstract type CommonHighlightRule end

"""
`userule(r::CommonHighlightRule, str::AbstractString, i::Int, stack, meta) -> Union{Tuple{Int, Pair}, Nothing}`

`nothing` will be return if the rule isn't successfully excuted\\
the integer shows where the next reading index shall be
"""
function userule end

function canuserule end

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
canuserule(::LineStartRule, ::AbstractString, i::Int, stack, meta)= i==1
function userule(r::LineStartRule, str::AbstractString, ::Int, stack, meta)
	if isa(r.pattern, Regex)
		f=findfirst(r.pattern, str)
		if f===nothing
			return nothing
		end
		if f.stop<patlength
			return nothing
		end
		return (f.stop+r.offset+1, r.hl_type => str[1:f.stop+r.offset])
	else
		if startswith(str, r.pattern)
			return (r.patlength+offset+1, r.hl_type => str[1:r.patlength+r.offset])
		else
			return nothing
		end
	end
end

"""
This rule checks `meta[:record_linestart]`
"""
struct RecordedLineStartRule <: CommonHighlightRule end
canuserule(::RecordedLineStartRule, ::AbstractString, i::Int, stack, meta)= i==1
function userule(::RecordedLineStartRule, str::AbstractString, ::Int, stack, meta)
	record=meta[:record_linestart]
	if startswith(str, record)
		return (sizeof(str)+1, :shell => record)
	else
		return nothing
	end
end

struct PlainAllRule <: CommonHighlightRule end
canuserule(::PlainAllRule, ::AbstractString, i::Int, stack, meta)= true
function userule(::RecordedLineStartRule, str::AbstractString, i::Int, stack, meta)
	return (sizeof(str)+1, :plain => str[i:end])
end
