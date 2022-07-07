struct RuleSet
	set::Vector{T} where T<: CommonHighlightRule
end
function useruleset(rs::RuleSet, lines::AbstractVector, stack, meta)
	for line in lines
		i=1
		while i<=sizeof(line)
		end
	end
end
