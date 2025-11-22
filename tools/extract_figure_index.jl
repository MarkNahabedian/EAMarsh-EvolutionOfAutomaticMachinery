using Pkg
Pkg.activate(; temp = true)

Pkg.add("Gumbo");     using Gumbo
Pkg.add("Cascadia");  using Cascadia
Pkg.add("XML");       using XML

const WATXH_BOOK = joinpath(dirname(@__DIR__),
                            "WatchMachineryBook.html")

const FIGURE_INDEX_FILE = joinpath(dirname(@__DIR__),
                            "figure_index.html")

watch_book_dom = parsehtml(read(WATXH_BOOK, String))

const FIGURE_SELECTOR = Cascadia.Selector("figure")
                      
function extract_index(dom)
    figure_anchors = []
    for figure_elt in eachmatch(FIGURE_SELECTOR, watch_book_dom.root)
        id = getattr(figure_elt, "id", missing)
        caption = text(first(eachmatch(Cascadia.Selector("figcaption"), figure_elt)))
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
