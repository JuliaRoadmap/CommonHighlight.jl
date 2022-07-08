struct RuleSet
	main::Vector{<:CommonHighlightRule}
	linestart::Vector{<:CommonHighlightRule}
end
function useruleset(rs::RuleSet, lines::AbstractVector, status)
	vec=Vector{Vector}()
	sizehint!(vec, length(lines))
	for line in lines
		thisline=Vector{Pair}()
		i=1
		status[:prev]=1
		sz=sizeof(line)
		for rule in rs.linestart
			res=userule(rule, thisline, line, i, status)
			if res!=0
				i=res
				break
			end
		end
		while true
			flag=true
			breaks=false
			for rule in rs.main
				res=userule(rule, thisline, line, i, status)
				if res!=0
					i=res
					if i>sz
						breaks=true
						break
					end
					flag=false
					break
				end
			end
			if breaks
				break
			end
			if flag
				i=nextind(line, i)
			end
		end
		if status[:prev]<i
			closeprev(thisline, str, status[:prev], sz+1, status)
		end
		push!(vec, thisline)
	end
	return vec
end
