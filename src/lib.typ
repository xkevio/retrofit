#let _wasm-bib = plugin("retrofit.wasm")
#let _bib-counter = counter("bib-counter")
#let _cited-pages(format, key) = context {
  let pages = query(<__cite>).filter(m => m.value == key).map(r => r.location())
  let links = pages.dedup(key: p => p.page()).map(p => link(p, str(counter(page).at(p).first())))
  if pages.len() > 0 { format(links) }
}

/// Using `backrefs` in a show-rule enables backreferences for each entry.
///
/// It does this by looking for all instances of a citation, collecting the pages
/// it is on and correctly assigns them to each bibliography entry.
///
/// === Example
/// ```typ
/// #show: backrefs.with(
///   format: l => [Cited on page(s) #l.join(", ")],
///   read: path => read(path),
/// )
/// ```
/// -> content
#let backrefs(
  /// Specifies how the links to the pages should be styled.
  /// The function takes an array of `link` as input and expects some markup as output.
  ///
  /// -> function
  format: links => [*(#links.join(", "))*],
  /// Specifies a function to process the `path` and `style` parameters of `#bibliography`.
  /// Pass ```typc path => read(path)``` to read the contents of the bibliography.
  ///
  /// _(This is currently needed for correctly resolving relative paths!)_
  /// -> function
  read: none,
  doc,
) = {
  assert.eq(
    type(format),
    function,
    message: "Please specify a function to turn the backreferences into markup!",
  )

  show cite: it => [#metadata(it.key)<__cite>] + it
  show bibliography: bib => {
    let keys = query(<__cite>).map(m => str(m.value)).dedup()
    let formats = bib.sources.map(s => {
      // @typstyle off
      if type(s) == bytes { "bytes" }
      else if s.ends-with(regex("ya?ml")) { "yml" }
      else { "bib" }
    })

    let sources = bib.sources.map(s => {
      if type(s) == str {
        read(s)
      } else {
        str(s)
      }
    })

    // Read in CSL content if necessary.
    let (style, style-format) = if bib.style.ends-with(".csl") {
      (read(bib.style), "csl")
    } else {
      (bib.style, "text")
    }

    let sorted-keys = str(_wasm-bib.sorted_bib_keys(
      bytes(sources.join("%%%")),
      bytes(formats.join(",")),
      bytes(if bib.full { "true" } else { "false" }),
      bytes(style),
      bytes(style-format),
      bytes(text.lang),
      bytes(keys.join(",")),
    )).split()

    // Track the highest-numbered entry seen so we can append a trailing
    // backref for the last entry (which has no following [N+1] to anchor on).
    let _last-n = state("retrofit-last-n", 0)

    // Numbered styles (IEEE, GB-7714, etc.): in typst >= 0.14 each entry
    // is no longer wrapped in its own grid row or block — bibliography
    // renders as one block of flowing text. But every entry still begins
    // with a standalone text element matching the literal pattern `[N]`,
    // which we use as the entry boundary anchor.
    //
    // Strategy: when we see `[N]` for N >= 2, prepend the backref for
    // entry N-1 (which sits immediately before this label in the flow).
    // For the final entry, append after `bib` renders. A zero-width-space
    // sentinel marks already-processed text to prevent show-rule recursion.
    show text: it => {
      let m = it.text.match(regex("^\[(\d+)\]$"))
      if m == none { return it }
      let n = int(m.captures.first())
      _last-n.update(prev => calc.max(prev, n))
      if n >= 2 and n - 1 <= sorted-keys.len() {
        _cited-pages(format, label(sorted-keys.at(n - 2))) + it
      } else {
        it
      }
    }

    bib

    // Append backref for the last numbered entry.
    context {
      let n = _last-n.get()
      if n >= 1 and n <= sorted-keys.len() {
        _cited-pages(format, label(sorted-keys.at(n - 1)))
      }
    }
  }

  doc
}
