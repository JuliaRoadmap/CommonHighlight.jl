function highlight_lines(::Val, content::AbstractString, setting::CommonHighlightSetting)
	parts=split(content, '\n'; keepempty=setting.keepempty)
	lines=map(s -> ("plain" => s,), parts)
	return HighlightLines{Tuple}(lines)
end
