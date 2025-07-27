#import "@preview/tidy:0.4.3"

#set page(height: auto)
#set text(font: "Liberation Sans")

#let docs = tidy.parse-module(read("../src/lib.typ"), name: "Retrofit")
#tidy.show-module(docs)
