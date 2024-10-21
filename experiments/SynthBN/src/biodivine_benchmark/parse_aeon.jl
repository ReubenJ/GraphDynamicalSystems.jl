module AEONParser
using ParserCombinator:
    Equal, Pattern, Drop, parse_one, parse_dbg, Trace, @with_names, set_name

using SoleLogics: parseformula, Atom, ∨, ∧, ¬, AbstractSyntaxStructure

using Term: Progress, ProgressBar

# See the following for source:
# https://biodivine.fi.muni.cz/aeon/manual/v0.4.0/model_editor/import_export.html#aeon-format

# > Since SBML is quite hard to edit by hand, as well as parse correctly,
# > we also provide a simplified text based format. In this format, the
# > regulatory graph is described as a list of edges, where each edge is
# > encoded as regulator [->,-|,-?,->?,-|?,-??] target. Here, regulator and
# > target are the names of the network variables, and the arrow connecting
# > them describes the type of regulation. Then -> denotes activation, -|
# > inhibition and -? is unspecified monotonicity. Finally, an extra ? signifies
# > that the regulation is non-observable.
# >
# > An update function for variable X is written as $A: function, where the format
# > of the actual functions in .aeon files is the same as in the edit fields in the
# > AEON interface. Additional information (model name, description and layout) is
# > encoded in comments (lines starting with #). The order of declarations is not
# > taken into account.
# > [...]

struct NetworkVar
    name::Any
end

@enum RegulationType begin
    activation
    inhibition
    unspecified
end

get_reg_type =
    reg_str -> Dict([">" => activation, "|" => inhibition, "?" => unspecified])[reg_str]

struct Regulation
    regulator::NetworkVar
    reg_type::RegulationType
    is_observable::Bool
    target::NetworkVar
end

struct UpdateFunction
    target::NetworkVar
    fn::AbstractSyntaxStructure
end

Regulation(reg::NetworkVar, reg_type::RegulationType, target::NetworkVar) =
    Regulation(reg, reg_type, true, target)

function parse_aeon_function_as_sole_function(formula::AbstractString)
    symbols_swapped = replace(formula, "&" => ∧, "|" => ∨, "!" => ¬)
    return parseformula(symbols_swapped)
end

@with_names begin
    # Matches "word" characters, ex: v_IL1R1, v_IRF2
    network_var = Pattern("\\w+") > NetworkVar
    # Matches 0 or more whitespace characters and ignores (drops) them
    spaces = Drop(Pattern("\\s")[0:end])
    # Matches the '-' character
    edge = Drop(Equal("-"))
    # Matches '>' or '|' or '?' and maps it to an activation type
    reg_type = (Equal(">") | Equal("|") | Equal("?")) > get_reg_type
    # Matches 0 or 1 '?' characters, then maps to false if 1, true if 0
    is_observable = Equal("?")[0:1] |> isempty

    regulation = spaces + edge + reg_type + is_observable + spaces

    regulation_line = (network_var + regulation + network_var) > Regulation

    fn_line_begin = Drop(Equal("\$"))

    fn_line =
        fn_line_begin +
        network_var +
        Drop(Equal(":")) +
        spaces +
        # Convert the rest into a SoleLogics function
        (Pattern(".")[0:end] |> join > parse_aeon_function_as_sole_function) >
        UpdateFunction

    each_line = (fn_line | regulation_line)
end

function parse_aeon_file(
    filepath::AbstractString,
    pbar::ProgressBar = Progress.FOREACH_PROGRESS,
)
    model = []
    Progress.foreachprogress(
        readlines(filepath),
        pbar;
        parallel = true,
        transient = true,
        description = "Parsing $(basename(filepath))",
    ) do l
        push!(model, parse_one(l, each_line))
    end
    model
end
end
