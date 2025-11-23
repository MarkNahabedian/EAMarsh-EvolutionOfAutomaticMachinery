# Verify consistency of page and page number related tags

using Pkg
Pkg.activate(; temp = true)

using Logging
Pkg.add("Gumbo");     using Gumbo
Pkg.add("Cascadia");  using Cascadia

const WATXH_BOOK = abspath(joinpath(dirname(@__DIR__),
                                    "WatchMachineryBook.html"))

watch_book_dom = parsehtml(read(WATXH_BOOK, String))


function verify_page_consistency(dom)
    ignore_tags = ["EDITING-NOTES"]
    valid_page_headings = [ "PREFACE.",
                            "INTRODUCTION.",
                            "EVOLUTION Or AUTOMATIC MACHINEPV."]
    current_page_number = nothing
    previous_page_number = nothing
    for bodychild in eachmatch(sel"html > body > *", dom.root)
        tagname = tag(bodychild)
        if tagname == :PAGE
            previous_page_number = current_page_number
            current_page_number = nothing
        elseif tagname == :a && haskey(bodychild.attrs, "name")
            name = getattr(bodychild, "name")
            m = match(r"^page-(<page>[0-9]+)$", name)
            if m isa Nothing
                @warn("PAGE.name has bad format", name)
            else
                current_page_number = parse(Int, m[:page])
                if previous_page_number != nothing &&
                    previous_page_number + 1 != current_page_number
                    @warn("Page numbers not sequential",
                          previous_page_number,
                          current_page_number)
                end
            end
        elseif tagname == Symbol("PAGE-NUMBER") && haskey(bodychild.attrs, "align")
            if !in(getattr(bodychild, "align"), ["left", "center", "right"])
                @warn("Unrecognized align", bodychild)
            end
            pn = text(bodychild)
            if parse(pn, Int) != current_page_number
                @warn("Page numbers don't match", current_page_number, pn)
            end
        elseif tagname == Symbol("PAGE-HEADING")
            heading = text(bodychild)
            if headiing != valid_page_headings[1]
                if heading == valid_page_headings[2]
                    popfirst!(valid_page_headings)
                else
                    @warn("page heading doesn't match",
                          heading,
                          expected = valid_page_headings[1:2])
                end
            end
        elseif tagname in ignore_tags
            # Ignore
        else
            @warn("Unimplemented tag $tagname")
        end
    end
end

verify_page_consistency(watch_book_dom)
