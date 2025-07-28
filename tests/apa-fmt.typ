#import "../src/lib.typ": backrefs

#set page(width: 15cm, height: auto)
#set par(justify: true)

#show: backrefs.with(
  format: l => text(gray)[(Cited on p. #l.join(", ", last: " and "))],
  read: path => read(path),
)

@Dobrushina
@newsviews

#pagebreak()

@DuweLMSF0B020
@Dobrushina

#bibliography("refs.bib", style: "apa")
