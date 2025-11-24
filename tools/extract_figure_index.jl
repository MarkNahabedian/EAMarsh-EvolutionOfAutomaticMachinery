using Pkg
Pkg.activate(; temp = true)

using Logging
using InteractiveUtils
Pkg.add("Gumbo");     using Gumbo
Pkg.add("Cascadia");  using Cascadia
Pkg.add("XML");       using XML

const WATCH_BOOK = abspath(joinpath(dirname(@__DIR__),
                                    "WatchMachineryBook.html"))

const FIGURE_INDEX_FILE = joinpath(dirname(@__DIR__),
                            "figure_index.html")

watch_book_dom = parsehtml(read(WATCH_BOOK, String))


function extract_index(dom)
    figure_anchors = []
    for figure_elt in eachmatch(sel"figure", dom.root)
        picture = check_figure(figure_elt)
        if picture !== nothing
            push!(figure_anchors, index_element(picture))
        end
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


abstract type AbstractFigure end

abstract type AbstractFigureErrror <: Exception end

struct FigureHasNoId <: AbstractFigureErrror
    figure_elt::HTMLElement
end

Base.showerror(e::FigureHasNoId) = "figure has no id: $(e.figure_elt)"

struct UnrecognizedFigure <: AbstractFigureErrror
    figure_elt::HTMLElement
    failed_matches
end

Base.showerror(e::UnrecognizedFigure) = "figure has no id: $(e.figure_elt)"

struct ImgSrcFormatError <: AbstractFigureErrror
    picture::AbstractFigure
end

Base.showerror(e::ImgSrcFormatError) = "src doesn't match regexp: $(e.picture)"


struct Figure <: AbstractFigure
    figure_elt::HTMLElement
    id::Union{Nothing, String}
    id_match::Union{Nothing, RegexMatch}
end

id_regexp(::Type{Figure}) = r"^figure-(?<figure>[0-9]+)(?<letter>[a-z]?)$"

src_regexp(::Figure) = r"^figures/page(?<page>[0-9]+)_figure(?<figure>[0-9]+)(?<letter>[a-z]?)[.]png$"

struct Portrait <: AbstractFigure
    figure_elt::HTMLElement
    id::Union{Nothing, String}
    id_match::Union{Nothing, RegexMatch}
end

id_regexp(::Type{Portrait}) = r"^portrait-(?<name>[A-Za-z]+)$"

src_regexp(::Portrait) = r"figures/page(?<page>[0-9]+)_portrait(?<name>[A-Za-z]+).png"


function index_element(picture::AbstractFigure)
    XML.Element("div",
                XML.Element("a",
                            XML.Text(first(eachmatch(sel"figcaption", picture.figure_elt)));
                            href="#$(picture.id)"))
end

function AbstractFigure(figure_elt::HTMLElement)
    id = getattr(figure_elt, "id", missing)
    if id isa Missing
        throw(FigureHasNoId(figure_elt))
    end
    picture = nothing
    failed_matches = []
    # Determine picture type and construct a representation
    for t in subtypes(AbstractFigure)
        m = match(id_regexp(t), id)
        if !isa(m, Nothing)
            picture = t(figure_elt, id, m)
            break
        else
            push!(failed_matches, (id, t))
        end
    end
    if picture isa Nothing
        # Failed to determine figure type, give up until that's fixed.
        throw(UnrecognizedFigure(figure_elt, failed_matches))
    end
    return picture
end

function check_picture_file_exists(picture::AbstractFigure, src::String)
    img_path = joinpath(dirname(WATCH_BOOK), src)
    if !isfile(img_path)
        @warn("Figure file missing", img_path)
    end
end

function check_figure(figure_elt::HTMLElement)
    img_count = 0
    try
        picture = AbstractFigure(figure_elt)
        for img in eachmatch(sel"img", figure_elt)
            img_count += 1
            src = getattr(img, "src", missing)
            if src isa Missing
                @warn("figure img has no src", figure_elt)
            else
                check_picture_file_exists(picture, src)
                m = match(src_regexp(picture), src)
                if m isa Nothing
                    throw(ImgSrcFormatError(picture))
                else
                    check_img(picture, img, src, m)
                end
            end
        end
        if img_count == 0
            @warn("No img tags within figure", piicture)
        end
        picture
    catch e
        if e isa AbstractFigureErrror
            @warn(e)
        else
            rethrow()
        end
    end
end

function check_img(picture::Figure, img::HTMLElement, src::String, m::RegexMatch)
    # Compare figure numbers in id and img@src:
    figure_number = parse(Int, picture.id_match[:figure])
    if figure_number != parse(Int, m[:figure])
        @warn("Figure number in file name doesn't match id",
              figure_number, src)
    end
end

function check_img(picture::Portrait, img::HTMLElement, src::String, m::RegexMatch)
    # Compare portrait subject name in id and img@src:
    name = picture.id_match[:name]
    if name != m[:name]
        @warn("Portrait name in file name doesn't match id",
              name, src)
    end
end


extract_index(watch_book_dom)

