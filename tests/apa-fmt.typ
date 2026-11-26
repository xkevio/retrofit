#import "../src/lib.typ": backrefs
#let theme = sys.inputs.at("theme", default: "light")

#set page(width: 15cm, height: auto, margin: 1cm, fill: if theme == "dark" { none })
#set text(white) if theme == "dark"
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
