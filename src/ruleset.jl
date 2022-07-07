struct RuleSet
	set::Vector{T} where T<: CommonHighlightRule
end
function useruleset(rs::RuleSet, lines::AbstractVector, stack, meta)
	vec=Vector{Vector}()
	sizehint!(vec, length(lines))
	for line in lines
		thisline=Vector{Pair}()
		i=1
		sz=sizeof(line)
		while true
			for rule in rs.set
				res=userule(rule, line, i, stack, meta)
				if res!==nothing
					(i, pair)=res
					push!(thisline, pair)
					if i>sz
						break
					end
				end
			end
		end
		push!(vec, thisline)
	end
	return vec
end
