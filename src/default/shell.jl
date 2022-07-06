function highlight_lines(::Union{Val{:shell}, Val{:sh}}, content::AbstractString, setting::CommonHighlightSetting)
	lines=split(content, '\n'; keepempty=setting.keepempty)
	vec=Vector{Tuple}()
	maystart=""
	sz=0
	l=length(lines)
	sizehint!(vec, l)
	for i in 1:l
		line=lines[i]
		if maystart!="" && startswith(line, maystart)
			len=length(line)
			if sz!=len
				push!(vec, ("shell" => maystart, "plain" => line[sz+1:len]))
			else
				push!(vec, ("shell" => maystart,))
			end
		elseif startswith(line, "\$ ")
			maystart="\$"
			sz=1
			push!(vec, ("shell" => "\$", "plain" => line[2:end]))
		else
			find=findfirst(r"^[a-zA-Z0-9_-]*(>|#|~) ", line)
			if find===nothing
				push!(vec, ("plain" => line,))
			else
				sz=find.stop-1
				maystart=line[1:sz]
				push!(vec, ("shell" => maystart, "plain" => line[find.stop:end]))
			end
		end
	end
	return HighlightLines{Tuple}(vec)
end
