#import "../src/lib.typ": backrefs

#set page(width: 15cm, height: auto, margin: 1cm, fill: none)
#set par(justify: true)

#show: backrefs.with(
  format: l => text(gray)[(Cited on p. #l.join(", ", last: " and "))],
  read: path => read(path),
)

@Dobrushina
@Wilde2019

#pagebreak()

@DuweLMSF0B020
@Dobrushina

#pagebreak()

#bibliography("refs.bib", style: "apa")
