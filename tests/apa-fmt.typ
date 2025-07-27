#import "../src/lib.typ": backrefs

#set page(width: 15cm, height: auto)
#set par(justify: true)

#show: backrefs.with(format: l => text(gray)[(Cited on p. #l.join(", ", last: " and "))])

@Dobrushina
@newsviews

#pagebreak()

@DuweLMSF0B020
@Dobrushina

#bibliography("/tests/refs.bib", style: "apa")
