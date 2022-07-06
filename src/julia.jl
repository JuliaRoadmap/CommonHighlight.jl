const jl_keywords=[
	"end", "if", "for", "else", "elseif", "function", "return", "while", "using", "try", "catch",
	"const", "struct", "mutable", "abstract", "type", "begin", "macro", "do",
	"break", "continue", "finally", "where", "module", "import", "global", "export",
	"local","quote","let",
	"baremodule","primitive"
]
const jl_specials=[
	"true", "false", "nothing", "missing"
]
function highlight_lines(::Union{Val{:jl}, Val{:julia}, Val{Symbol("jl-repl")}}, content::AbstractString, setting::CommonHighlightSetting)
	lines=split(content, '\n'; keepempty=setting.keepempty)
	vec=Vector{Vector}()
	sizehint!(vec, length(lines))
	hasrepl=true
	stack=Vector{UInt8}()
	b_stack=Vector{UInt16}() # 用于 $( 的括号栈
	prestr=""
	#=
	0	$(
	1	"
	2	`
	3	"""
	4	\#\=
	=#
	for line in lines
		if line==""
			push!(vec, ())
			continue
		end
		thisline=Vector{Pair}()
		push!(vec, thisline)
		sz=thisind(line, sizeof(line))
		i=1
		pre=1
		emp=isempty(stack)
		weakemp=emp || last(stack)==0x0
		dealf= (to::Int= prevind(line, i)) -> begin
			push!(thisline,
				(weakemp ? "plain" : "string") => prestr*line[pre:to]
			)
			prestr=""
		end
		# REPL特殊处理尝试
		if emp
			if startswith(line, "julia>")
				hasrepl=true
				push!(thisline, "repl-code" => "julia>")
				pre=i=7
			elseif startswith(line, "help?>")
				push!(thisline, "repl-help" => "help?>")
				pre=i=7
			elseif startswith(line, "shell>")
				push!(thisline, "repl-shell" => "shell>")
				pre=i=7
			else
				f=findfirst(r"^\([0-9a-zA-Z._@]*\) pkg>", line)
				if f!==nothing
					push!(thisline, "repl-pkg" => line[1:f.stop])
					pre=i=f.stop+1
				elseif startswith(line, "ERROR:") && hasrepl
					push!(thisline, "repl-error" => "ERROR:")
					pre=i=7
				elseif startswith(line, "caused by:") && hasrepl
					push!(thisline, "repl-error" => "caused by:")
					pre=i=11
				end
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
					elseif !(Base.is_id_char(line[j]) || co[j]==' ' || co[j]==',' || co[j]==':')
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
						push!(thisline, "string" => prestr*line[pre:end])
						prestr=""
						break
					else
						push!(thisline, "string" => prestr*line[pre:i])
						prestr=""
						pop!(stack)
						pre=i=i+1
					end
				elseif last(stack)==0x3 # 闭合"""字符串
					if i>sz-2
						push!(thisline, "string" => prestr*line[pre:end])
						prestr=""
						break
					end
					if line[i+1]=='"' && line[i+2]=='"'
						push!(thisline, "string" => prestr*line[pre:i+2])
						prestr=""
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
				push!(thisline, "escape" => co[i:i+1])
				pre=i=nextind(co, i+1)
			elseif inside && ch=='$'
				j=i+1; ch=line[j]
				if ch=='('
					dealf()
					push!(thisline, "insert" => "\$(")
					push!(stack, 0x0)
					push!(b_stack, zero(UInt16))
					pre=i=i+2
				elseif Base.is_id_start_char(ch)
					dealf()
					j=nextind(co, j)
					while j<=sz && Base.is_id_char(line[j])
						j=nextind(line, j)
					end
					if j>sz
						push!(thisline, "insert" => line[i:end])
						break
					else
						push!(thisline, "insert" => line[i:prevind(line, j)])
						pre=i=j
					end
				else
					i+=1
				end
			elseif weakemp && ch=='@'
				j=i+1
				if Base.is_id_start_char(line[j])
					dealf()
					j=nextind(co, j)
					while j<=sz && Base.is_id_char(line[j])
						j=nextind(co, j)
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
					push!(thisline, "string" => prestr*line[pre:i])
					prestr=""
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
				if j!=sz && (co[j]=='x' || co[j]=='o') j+=1 end
				while j<=sz && ('0'<=co[j]<='9' || 'a'<=co[j]<='f' || co[j]=='_')
					j+=1
				end
				if j>sz
					push!(thisline, "number" => line[i:end])
					return s
				else
					push!(thisline, "number" => line[i:prevind(line, j)])
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
					push!(thisline, prestr*line[pre:end])
					prestr=""
					break
				elseif line[i+1]=='#' # 闭合多行注释
					if !emp && last(stack)==0x4
						pop!(stack)
						push!(thisline, prestr*line[pre:i+1])
						prestr=""
						pre=i=i+2
					else
						i+=1
					end
				end
			elseif !emp && last(stack)==0x0 && ch=='('
				dealf()
				push!(thisline, "insert" => "(")
				b_stack[end]+=one(UInt16)
				pre=i=i+1
			elseif !emp && last(stack)==0x0 && ch==')'
				dealf()
				push!(thisline, "insert" => ")")
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
			prestr*=line[pre:end]
		end
	end
	return HighlightLines{Vector}(vec)
end