#let _wasm-bib = plugin("retrofit.wasm")
#let _bib-counter = counter("bib-counter")
#let _cited-pages(
  format: links => [*(#links.join(", "))*],
  key,
) = context {
  let pages = query(ref.where(target: key)).map(r => r.location())
  let links = pages.map(p => link(p, str(p.page())))
  format(links)
}

/// Using `backrefs` in a show-rule enables backreferences for each entry.
///
/// It does this by looking for all instances of a citation, collecting the pages
/// it is on and correctly assigns them to each bibliography entry.
///
/// === Example
/// ```typ
/// #show: backrefs.with(format: l => [Cited on page(s) #l.join(", ")])
/// ```
/// -> content
#let backrefs(
  /// Specifies how the links to the pages should be styled.
  /// The function takes an array of `link` as input and expects some markup as output.
  ///
  /// -> function
  format: links => [*(#links.join(", "))*],
  doc,
) = {
  assert.eq(
    type(format),
    function,
    message: "Please specify a function to turn the backreferences into markup!",
  )

  show bibliography: bib => {
    let keys = query(ref.where(element: none)).dedup().map(r => str(r.target))
    let sources = bib.sources.map(s => {
      if type(s) == str {
        read(s)
      } else {
        str(s)
      }
    })

    let sorted-keys = str(_wasm-bib.sorted_bib_keys(
      bytes(sources.join("%%%")),
      bytes(if bib.full { "true" } else { "false" }),
      bytes(bib.style),
      bytes(if bib.style.ends-with(".csl") { "csl" } else { "text" }),
      bytes(text.lang),
      bytes(keys.join(",")),
    )).split()

    // Grid-based styles, such as IEEE.
    show grid: it => {
      if not it.has("label") {
        // Modify every second child which represents the entry itself.
        let modified-children = it
          .children
          .enumerate()
          .map(((i, c)) => {
            if calc.odd(i) {
              _bib-counter.step()
              (
                c
                  + " "
                  + context {
                    let idx = _bib-counter.get().first() - 1
                    _cited-pages(format: format, label(sorted-keys.at(idx)))
                  }
              )
            } else {
              c
            }
          })

        let fields = it.fields()
        let _ = fields.remove("children")

        [#grid(..fields, ..modified-children)<grid>]
      } else {
        it
      }
    }

    // Non-grid based styles (blocks with v-spacing), such as APA.
    show block: it => {
      if it.sticky or it.body == auto { return it } // todo: see if this is solid.
      if not it.has("label") {
        let modified-body = (
          it.body
            + " "
            + context {
              let idx = _bib-counter.get().first() - 1
              _cited-pages(format: format, label(sorted-keys.at(idx)))
            }
        )
        _bib-counter.step()

        let fields = it.fields()
        let _ = fields.remove("body")

        [#block(..fields, modified-body)<block>]
      } else {
        it
      }
    }

    bib
  }

  doc
}
