function highlight_lines(::Union{Val{:shell}, Val{:sh}}, content::AbstractString, setting::CommonHighlightSetting)
	lines=split(content, '\n'; keepempty=setting.keepempty)
	vec=Vector{Tuple}()
	sizehint!(vec, length(lines))
	meta=Dict(:record_linestart => "")
	vec=useruleset(RuleSet([
		dollar_rule=LineStartRule(;pattern="\$ ", patlength = 2,offset=-1),
		long_rule=LineStartRule(;pattern=r"^[a-zA-Z0-9_-]*(>|#|~) ", offset=-1),
		plain_rule=PlainAllRule()
	]), lines, nothing, meta)
	return HighlightLines{Tuple}(vec)
end
