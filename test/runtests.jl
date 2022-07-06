using CommonHighlight
using Test

@testset "CommonHighlight" begin
	setting=CommonHighlightSetting()
	@testset "Plain" begin
		t_pl=(str::String, res::Vector) -> begin
			highlight_lines(:plain, str, setting).lines == res
		end
		@test t_pl("1\n2", [("plain" => "1",), ("plain" => "2",)])
		@test t_pl("1\n2\n", [("plain" => "1",), ("plain" => "2",), ("plain" => "",)])
		@test t_pl("1\n\n2", [("plain" => "1",), ("plain" => "",), ("plain" => "2",)])
	end
	@testset "Shell" begin
		s_pl=(str::String, res::Vector) -> begin
			highlight_lines(:shell, str, setting).lines == res
		end
		@test s_pl("\$ login\n\$ ls\n1.txt", [
			("shell" => "\$", "plain" => " login"),
			("shell" => "\$", "plain" => " ls"),
			("plain" => "1.txt",)
		])
		@test s_pl("vir> cat 文字\nvir>", [
			("shell" => "vir>", "plain" => "cat 文字"),
			("shell" => "vir>",)
		])
		@test s_pl("vir> \$ 文字\nvir> ", [
			("shell" => "vir>", "plain" => " \$ 文字"),
			("shell" => "vir>", "plain" => " ")
		])
		@test s_pl("vir>文\nvir> ", [
			("plain" => "vir>文",),
			("shell" => "vir>", "plain" => " ")
		])
	end
	@testset "Julia" begin
		j_pl=(str::String, res::Vector) -> begin
			highlight_lines(:jl, str, setting).lines == res
		end
		@test j_pl("#注释", [
			("comment" => "#注释",)
		])
		@test j_pl("for i in 1:3\nend", [
			("keyword" => "for", "plain" => " i in ", "number" => "1", "plain" => ":", "number" => "3"),
			("keyword" => "end",)
		])
		@test j_pl("@inbounds [nothing][0];", [
			("macro" => "@inbounds", "plain" => " [", "special" => "nothing", "plain" => "][", "number" => "0", "plain" =>"];"),
		])
		@test j_pl("julia> v = String('a')\nERROR: MethodError:", [
			("shell" => "julia>", "plain" => " v = ", "type" => "String", "plain" => "(", "string" => "'a'", "plain" => ")"),
			("repl-error" => "ERROR:", "type" => "MethodError", "plain" => ":")
		])
		@test j_pl("\"\"\"multi\njulia> \\t\n\t\"\"\"", [
			("string" => "\"\"\"multi",),
			("string" => "julia> ", "escape" => "\\t"),
			("string" => "\t\"\"\"",)
		])
		@test j_pl("#= \"\" #= #\n=# #\n =# #1", [
			("comment" => "#= \"\" #= #",),
			("comment" => "=# #",),
			("comment" => " =#", "plain" => " ", "comment" => "#1"),
		])
		@test j_pl("\"(\$插入)\"", [
			("string" => "\"(", "interpolation" => "\$插入", "string" => ")\"")
		])
		@test j_pl("Array{Int, 3}{", [
			("type" => "Array{Int, 3}", "plain" => "{")
		])
		@test j_pl(raw"\x333\a\ufffff", [
			("escape" => "\\x33", "plain" => "3", "escape" => "\\a", "escape" => "\\uffff", "plain" => "f")
		])
		str=raw"""
		str = @查看 "($("猫"*"\t"))
		\t$a $("[$(0)]"+a()+b(c()))符 \\\\
		# " '符'
		"""
		@test j_pl(str, [
			(
				"plain" => "str = ", "macro" => "@查看", "plain" =>" ",
				"string" => "\"(", "interpolation" => "\$(",
				"string" => "\"猫\"", "plain" => "*",
				"string" => "\"", "escape" => "\\t", "string" => "\"",
				"interpolation" => ")", "string" => ")"
			),
			(
				"escape" => "\\t", "interpolation" => "\$a", "plain" => " ",
				"interpolation" => "\$(", "string" => "\"[",
				"interpolation" => "\$(", "number" => "0", "interpolation" => ")",
				"string" => "]\"", "plain" => "+a",
				"interpolation" => "(", "interpolation" => ")",
				"plain" => "+b", "interpolation" => "(", "interpolation" => "(",
				"plain" => "c", "interpolation" => "(", "interpolation" => ")",
				"interpolation" => ")", "interpolation" => ")",
				"plain" => "符 ", "escape" => "\\\\", "escape" => "\\\\"
			),
			("string" => "# \"", "plain" => " ", "string" => "'符'")
		])
	end
end
