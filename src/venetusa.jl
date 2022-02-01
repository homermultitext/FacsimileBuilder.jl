"Builder including unique features of the Venetus A manuscript."
struct VenetusAFacsimile <: AbstractFacsimile
    dsec::DSECollection
    corpus::CitableTextCorpus
    codex::Vector{MSPage}
    scholiaindex
end

function surfacesequence(va::VenetusAFacsimile)
    va.codex
end

function mdpageheader(va::VenetusAFacsimile, pg::Cite2Urn)
    matches = filter(p -> urnequals(pg, p.urn), va.codex)
    if length(matches) == 1
        "## $(matches[1] |> label)"
       
    elseif isempty(matches)
        "(Error:  no page data found for $(pg))"
    else
        "(Error:  $(length(matches)) pages found matching $(pg))"
    end
end



"""Compose Venetus A facsimile. By default, creates a facsimile 
of all pages. Optionally, a list of page URNs can be provided in  `selection`.
$(SIGNATURES)
"""
function vapages(vafacs::VenetusAFacsimile; selection = [], navigation = true)
    pagelist = isempty(selection) ? map(pg -> pg.urn, vafacs.codex) : selection
    mdpages = []
    for pg in pagelist
        push!(mdpages, vapage(vafacs, pg, navigation = navigation))
    end
    mdpages
end

function vapage(vafacs::VenetusAFacsimile, pg::Cite2Urn; navigation = true)
    pgtxt = []
    mdheader = mdpageheader(vafacs, pg)
    # pg header
    push!(pgtxt, mdheader)
    # collect psgs
    psgs = []
    pagedse = filter(trip -> trip.surface == pg, vafacs.dsec.data)
    iliadurn = CtsUrn("urn:cts:greekLit:tlg0012.tlg001:")
    iliad = filter(trip -> urncontains(iliadurn, trip.passage),  pagedse)
    if ! isempty(iliad)
        psgcount = length(iliad)
        push!(pgtxt, "### *Iliad*\n\n($(psgcount) lines)")
    end

    othertexts = filter(trip -> ! urncontains(iliadurn, trip.passage),  pagedse)
    if ! isempty(othertexts)
        othercount = length(othertexts)
        push!(pgtxt, "### Other texts\n\n($(othercount) lines)")
    end
    #=
    psgmd = join(psgs, "\n\n---\n\n")
    @warn("Adding to pgtxt $(psgmd)")
    push!(pgtxt, psgmd)
    =#
    footer = navigation ? navlinks(vafacs, pg) : ""
    push!(pgtxt, footer)

    join(pgtxt, "\n\n")
end



function diplomaticforpage()
end

function navlinks(va::VenetusAFacsimile, pg::Cite2Urn)
    @warn("Navigation links not yet implemented.")
    ""
end

"""Create a `VenetusAFacsimile` builder from the HMT Archive.
$(SIGNATURES)
"""
function vabuilder(hmt::Archive)
    @info("Assembling facsimile builder for Venetus A MS")
    @info("1/4. Loading diplomatic corpus")
    dip = diplomaticcorpus(hmt)
    @info("2/4. Loading DSE data")
    triples = dse(hmt)
    @info("3/4. Loading codex data")
    codicesraw = hackcodices(hmt)
    mspages = filter(c -> !isnothing(c), codicesraw)
    vapages = filter( pg -> urncontains(Cite2Urn("urn:cite2:hmt:msA:"), pg.urn), mspages)
    @info("4/4. Indexing scholia to Iliad passages")
    index = commentpairs(hmt)
    VenetusAFacsimile(triples, dip, vapages, index)
end


### --------------- REPLACE THIS CHUNK ------------------------- ####
#
# Q&D temporary hacks until better solutoin in `HmtArchive` package:
function hackcodices(hmt::Archive)
    coddcex = HmtArchive.codexcex(hmt)
    codexpages = []
    for pg in data(coddcex, "citedata")
        push!(codexpages, hackcodex(pg))
    end
    codexpages
end
function hackcodex(ln::AbstractString)
    #=
#!citedata

-2|urn:cite2:hmt:msA.v1:insidefrontcover|verso|Venetus A (Marciana 454 = 822), \
inside front cover|urn:cite2:hmt:vaimg.2017a:VAMSInside_front_cover_versoN_0500
-1|urn:cite2:hmt:msA.v1:ir|recto|Venetus A (Marciana 454 = 822), folio i, recto\
|urn:cite2:hmt:vaimg.2017a:VAMSFolio_i_rectoN_0001
    =#
    @debug("Compare sequence|urn|rv|label|image with ", ln)
    cols = split(ln, "|")
    try 
        seq = parse(Int64, cols[1])
        u = Cite2Urn(cols[2])
        rv = cols[3]
        lbl = cols[4]
        img = Cite2Urn(cols[5])
        MSPage(u, lbl, rv, img, seq)
    catch
        @warn("Failed to parse $(ln)")
        nothing
    end
end
