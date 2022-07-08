const jl_keywords=[
	"end", "if", "for", "else", "elseif", "function", "return", "while", "using", "try", "catch",
	"const", "struct", "mutable", "abstract", "type", "begin", "macro", "do",
	"break", "continue", "finally", "where", "module", "import", "global", "export",
	"local", "quote", "let",
	"baremodule", "primitive"
]
const jl_specials=[
	"true", "false", "nothing", "missing"
]
function highlight_lines(::Union{Val{:jl}, Val{:julia}, Val{Symbol("jl-repl")}}, content::AbstractString, setting::CommonHighlightSetting)
	lines=split(content, '\n'; keepempty=setting.keepempty)
	status=Dict(:stack => Vector{UInt8}(), :b_stack => Vector{UInt16}())
	vec=useruleset( RuleSet([
		IDRule(Base.is_id_start_char, Base.is_id_char,
			(vec, line::AbstractString, from::Int, over::Int, chunk::AbstractString, status) -> begin
				if in(chunk, jl_keywords)
					closeprev(vec, line, from, over, status)
					push!(vec, :keyword => chunk)
					status[:prev]=over
					return over
				elseif in(chunk, jl_specials)
					closeprev(vec, line, from, over, status)
					push!(vec, :special => chunk)
					status[:prev]=over
					return over
				elseif over>sizeof(line)
					closeprev(vec, line, from, over, status)
					return over
				end
				return 0
			end
		),
	], [
		EmptyRule(),
		LineStartRule(; pattern="julia>", patlength=6),
		LineStartRule(; pattern="help?>", patlength=6, hl_type=:help),
		LineStartRule(; pattern="shell>", patlength=6, hl_type=:repl_shell),
		LineStartRule(; pattern=r"^\([0-9a-zA-Z._@]*\) pkg>", hl_type=:repl_pkg),
	]), lines, status)

	for line in lines
		i=1
		pre=1
		emp=isempty(stack)
		weakemp=emp || last(stack)==0x0
		dealf= (to::Int= prevind(line, i)) -> begin
			str=line[pre:to]
			if str!=""
				push!(thisline, (weakemp ? "plain" : "string") => str)
				pre=i
			end
		end
		while i<=sz
			emp=isempty(stack)
			weakemp=emp || last(stack)==0x0
			inside=!emp && 0x1<=last(stack)<=0x3
			ch=line[i]
			while ch==' ' || ch=='\t'
				i+=1
				ch=line[i]
			end
			if weakemp && 'A'<=ch<='Z' # 推测是类型
				dealf()
				j=i+1
				st=0; instr=false
				while j<=sz
					if instr
						if line[j]=='\\'
							j+=2
						elseif line[j]=='"'
							instr=false
						end
						continue
					end
					if line[j]=='{' st+=1
					elseif line[j]=='}'
						st==1 ? break : st-=1
					elseif line[j]=='"' && st!=0
						instr=true
					elseif !(Base.is_id_char(line[j]) || line[j]==' ' || line[j]==',' || line[j]==':')
						break
					end
					j=nextind(line, j)
				end
				if j>sz
					push!(thisline, "type" => line[i:end])
					break
				else
					push!(thisline, "type" => line[i:prevind(line, j)])
					pre=i=j
				end
			elseif weakemp && Base.is_id_start_char(ch) # 推测是变量等
				j=nextind(line, i)
				while j<=sz && Base.is_id_char(line[j])
					j=nextind(line, j)
				end
				str=line[i:prevind(line, j)]
				if in(str, jl_keywords)
					dealf()
					push!(thisline, "keyword" => str)
				elseif in(str, jl_specials) || (hasrepl && str=="ans")
					dealf()
					push!(thisline, "special" => str)
				elseif j>sz
					push!(thisline, "plain" => line[pre:end])
					break
				elseif line[j]=='('
					dealf()
					push!(thisline, "function" => str)
				else
					i=j
					continue
				end
				i=j
				pre=j
			elseif ch=='"'
				if weakemp # 新字符串
					dealf()
					pre=i
					if i==sz
						push!(stack, 0x1)
						break
					end
					if line[i+1]=='"'
						if i+1==sz # 末尾&空
							push!(thisline, "string" => "\"\"")
							break
						elseif line[i+2]!='"' # 空字符串
							push!(thisline, "string" => "\"\"")
							i+=2
							pre=i
							continue
						end
						# """字符串
						push!(stack, 0x3)
						i+=3
					else
						# "字符串
						push!(stack, 0x1)
						i+=1
					end
				elseif last(stack)==0x1 # 闭合"字符串
					if i==sz # 末尾
						push!(thisline, "string" => line[pre:end])
						break
					else
						push!(thisline, "string" => line[pre:i])
						pop!(stack)
						pre=i=i+1
					end
				elseif last(stack)==0x3 # 闭合"""字符串
					if i>sz-2
						push!(thisline, "string" => line[pre:end])
						break
					end
					if line[i+1]=='"' && line[i+2]=='"'
						push!(thisline, "string" => line[pre:i+2])
						pop!(stack)
						pre=i=i+3
					else
						i+=1
					end
				else # 0x2, 0x4
					i+=1
				end
			elseif weakemp && ch=='\''
				dealf()
				j=nextind(line, i)
				while j<=sz
					if line[j]=='\''
						break
					elseif line[j]=='\\'
						j+=1
					end
					j=nextind(line, j)
				end
				if j>sz
					push!(thisline, "string" => line[i:end])
					break
				end
				push!(thisline, "string" => line[i:prevind(line, j)])
				pre=i=j
			elseif inside && ch=='\\'
				dealf()
				if i==sz
				else
					ch=line[i+1]
					j=i+2
					if ch=='x'
						if i+3<=sz && isxdigit(line[i+3])
							j=i+4
						end
					elseif ch=='u'
						limit=min(sz, i+5)
						while j<=limit && isxdigit(line[j])
							j+=1
						end
					elseif ch=='U'
						limit=min(sz, i+9)
						while j<=limit && isxdigit(line[j])
							j+=1
						end
					elseif '0'<=ch<='7'
						limit=min(sz, i+3)
						while j<=limit && '0'<=line[j]<='7'
							j+=1
						end
					end
					if j>sz
						push!(thisline, "escape" => line[i:end])
						break
					end
					push!(thisline, "escape" => line[i:j-1])
					pre=i=j
				end
			elseif inside && ch=='$'
				j=i+1; ch=line[j]
				if ch=='('
					dealf()
					push!(thisline, "interpolation" => "\$(")
					push!(stack, 0x0)
					push!(b_stack, zero(UInt16))
					pre=i=i+2
				elseif Base.is_id_start_char(ch)
					dealf()
					j=nextind(line, j)
					while j<=sz && Base.is_id_char(line[j])
						j=nextind(line, j)
					end
					if j>sz
						push!(thisline, "interpolation" => line[i:end])
						break
					else
						push!(thisline, "interpolation" => line[i:prevind(line, j)])
						pre=i=j
					end
				else
					i+=1
				end
			elseif weakemp && ch=='@'
				j=i+1
				if Base.is_id_start_char(line[j])
					dealf()
					j=nextind(line, j)
					while j<=sz && Base.is_id_char(line[j])
						j=nextind(line, j)
					end
					if j>sz
						push!(thisline, "macro" => line[i:end])
						break
					else
						push!(thisline, "macro" => line[i:prevind(line, j)])
						pre=i=j
					end
				else
					i+=1
				end
			elseif ch=='`'
				if weakemp # 命令
					dealf()
					pre=i
					push!(stack, 0x2)
					i+=1
				elseif last(stack)==0x2 # 闭合`
					push!(thisline, "string" => line[pre:i])
					pop!(stack)
					pre=i=i+1
				else
					i+=1
				end
			elseif weakemp && '0'<=ch<='9' # 推测是数字
				dealf()
				if i==sz
					push!(thisline, "number" => "$ch")
				end
				j=i+1
				if j!=sz && (line[j]=='x' || line[j]=='o' || line[j]=='b') j+=1 end
				while j<=sz && ('0'<=line[j]<='9' || 'a'<=line[j]<='f' || line[j]=='_')
					j+=1
				end
				if j>sz
					push!(thisline, "number" => line[i:end])
					break
				else
					push!(thisline, "number" => line[i:j-1])
					pre=i=j
				end
			elseif weakemp && ch=='#'
				dealf()
				if i==sz
					push!(thisline, "comment" => "#")
					break
				elseif line[i+1]=='=' # 多行注释
					push!(stack, 0x4)
				else # 单行注释
					push!(thisline, "comment" => line[i:end])
					break
				end
			elseif !emp && last(stack)==0x4 && ch=='='
				if i==sz
					push!(thisline, line[pre:end])
					break
				elseif line[i+1]=='#' # 闭合多行注释
					if !emp && last(stack)==0x4
						pop!(stack)
						push!(thisline, line[pre:i+1])
						pre=i=i+2
					else
						i+=1
					end
				end
			elseif !emp && last(stack)==0x0 && ch=='('
				dealf()
				push!(thisline, "interpolation" => "(")
				b_stack[end]+=one(UInt16)
				pre=i=i+1
			elseif !emp && last(stack)==0x0 && ch==')'
				dealf()
				push!(thisline, "interpolation" => ")")
				if b_stack[end]==zero(UInt16)
					pop!(b_stack)
					pop!(stack)
					pre=i=i+1
				else
					b_stack[end]-=one(UInt16)
				end
			else
				i=nextind(line, i)
			end
		end
		if pre<i
			push!(thisline, (weakemp ? "plain" : "string") => line[pre:end])
		end
		push!(vec, thisline)
	end
	return HighlightLines{Vector}(vec)
end
