module CommonHighlight
export HighlightLines, highlight_lines

struct HighlightLines{T}
	lines::Vector{T}
end
Base.@kwdef struct CommonHighlightSetting
	keepempty::Bool = true
end

function highlight_lines(language::Symbol, content::AbstractString, setting::CommonHighlightSetting=CommonHighlightSetting())
	# if hasmethod(highlight_lines, (Val{language}, typeof(content), CommonHighlightSetting))
	return highlight_lines(Val(language), content, setting)
end

include("plain.jl")
include("shell.jl")
include("julia.jl")

end
