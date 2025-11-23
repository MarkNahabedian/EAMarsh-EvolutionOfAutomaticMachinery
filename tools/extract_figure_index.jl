using Pkg
Pkg.activate(; temp = true)

using Logging
Pkg.add("Gumbo");     using Gumbo
Pkg.add("Cascadia");  using Cascadia
Pkg.add("XML");       using XML

const WATXH_BOOK = abspath(joinpath(dirname(@__DIR__),
                                    "WatchMachineryBook.html"))

const FIGURE_INDEX_FILE = joinpath(dirname(@__DIR__),
                            "figure_index.html")

watch_book_dom = parsehtml(read(WATXH_BOOK, String))

const FIGURE_SELECTOR = Cascadia.Selector("figure")

const FIGURE_ID_REGEXP = r"^figure-(?<figure>[0-9]+)$"

const FIGURE_FILE_REGEXP =
    r"^figures/page(?<page>[0-9]+)_figure(?<figure>[0-9]+)(?<letter>[a-z]?)[.]png$"


function extract_index(dom)
    figure_anchors = []
    for figure_elt in eachmatch(FIGURE_SELECTOR, watch_book_dom.root)
        id = getattr(figure_elt, "id", missing)
        caption = text(first(eachmatch(Cascadia.Selector("figcaption"), figure_elt)))
        # Consistency checks:
        figure_number = nothing
        if id isa Missing
            @warn("Figure has no id", figure_elt)
        else
            m = match(FIGURE_ID_REGEXP, id)
            if m isa Nothing
                @warn("figure id has wrong format", id)
            else
                figure_number = parse(Int, m[:figure])
            end
        end
        img_count = 0
        for img in eachmatch(sel"img", figure_elt)
            img_count += 1
            src = getattr(img, "src", missing)
            if src isa Missing
                @warn("figure img has no src", figure_elt)
            else
                m = match(FIGURE_FILE_REGEXP, src)
                if m isa Nothing
                    @warn("""Wrong figure file format for "$src".""")
                else
                    if figure_number != parse(Int, m[:figure])
                        @warn("Figure number in file name doesn't match id",
                              figure_number, src)
                    end
                end
                img_path = joinpath(dirname(WATXH_BOOK), src)
                if !isfile(img_path)
                    @warn("Figure file missing", img_path)
                end
            end
        end
        if img_count == 0
            @warn("No img tags within figure")
        end
        # Add the figure to the index:
        push!(figure_anchors,
              XML.Element("div",
                          XML.Element("a",
                                      XML.Text(caption);
                                      href="#$id")))
    end
    open(FIGURE_INDEX_FILE, "w") do io
        XML.write(io,
                  XML.Element("FIGURE-INDEX",
                              XML.Comment(" The figure index was automatically generated bu $(basename(@__FILE__)) "), 
                              XML.Element("h2", XML.Text("Index of Figures")),
                              figure_anchors...);
                  indentsize=2)
    end
end

extract_index(watch_book_dom)
