module CommonHighlight
export HighlightLines, CommonHighlightSetting, highlight_lines

struct HighlightLines{T}
	lines::Vector{T}
end
function Base.show(io::IO, ::MIME"text/html", hll::HighlightLines)
	for line in hll.lines
		for chunk in line
			str=chunk.second
			str=replace(str, '&' => "&quot;")
			str=replace(str, '<' => "&lt;")
			str=replace(str, '>' => "&gtl")
			print(io, "<span class='hl-$(chunk.first)'>$str</span>")
		end
	end
end
html(hll::HighlightLines)=sprint(Base.show, MIME("text/html"), hll)

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
