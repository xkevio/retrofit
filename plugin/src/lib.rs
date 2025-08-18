use core::str;

use anyhow::{anyhow, bail, Result};
use hayagriva::{
    archive::{locales, ArchivedStyle},
    citationberg::{IndependentStyle, LocaleCode, Style},
    io::{from_biblatex_str, from_yaml_str},
    BibliographyDriver, BibliographyRequest, CitationItem, CitationRequest, Library, Rendered,
};
use wasm_minimal_protocol::*;

initiate_protocol!();

/// Generates a `Rendered` hayagriva bibliography object based on the given arguments.
/// - `bib` represents the contents of either a BibTeX file, hayagriva YAML file or `bytes`.
/// - `formats` consists of the bibliography types for faster parsing, such as "bib" or "yml".
/// - `full` represents whether to include all works from the given bibliography files.
/// - `style` may either represent the raw text of the given CSL style or its `ArchivedName`.
/// - `style_format` should be `csl | text` to tell the function what to do with `style`.
/// - `lang` represents an RFC 1766 language code.
/// - `cited` should contain all used citations even when `full: true`.
pub(crate) fn generate_bibliography(
    bib: &[&str],
    formats: &[&str],
    full: bool,
    style: &str,
    style_format: &str,
    lang: &str,
    cited: &[&str],
) -> Result<Rendered> {
    // Merge multiple bibliographies into one, be it BibTeX or YAML format.
    let bib =
        bib.iter()
            .enumerate()
            .try_fold(Library::new(), |mut acc, (i, s)| -> Result<Library> {
                let library = match formats[i] {
                    "bib" => from_biblatex_str(s).map_err(|e| anyhow!("{e:?}"))?,
                    "yml" => from_yaml_str(s)?,
                    "bytes" => from_biblatex_str(s).or_else(|_| from_yaml_str(s))?,
                    _ => unreachable!(),
                };

                for entry in library {
                    acc.push(&entry);
                }

                Ok(acc)
            })?;

    // If `style_format` is "csl", we expect Typst to pass the raw file contents for us,
    // as we cannot read from the filesystem as a WASM application. Otherwise, use `archive`.
    let style = if style_format == "csl" {
        IndependentStyle::from_xml(style)?
    } else {
        let archived_style =
            ArchivedStyle::by_name(style).ok_or(anyhow!("Could not find {style}"))?;
        match archived_style.get() {
            Style::Independent(indep) => indep,
            _ => bail!("Invalid independent style: {style} is dependent!"),
        }
    };

    let locales = locales();
    let locale_code = Some(LocaleCode(String::from(lang)));
    let mut driver = BibliographyDriver::new();

    // Add all found citations in the document to the driver.
    for key in cited {
        if let Some(entry) = bib.get(key) {
            let items = vec![CitationItem::with_entry(entry)];
            driver.citation(CitationRequest::new(
                items,
                &style,
                locale_code.clone(),
                &locales,
                None,
            ));
        }
    }

    // Add additional hidden entries if `full` is specified and all entries should be rendered.
    if full {
        for entry in &bib {
            driver.citation(CitationRequest::new(
                vec![CitationItem::new(entry, None, None, true, None)],
                &style,
                locale_code.clone(),
                &locales,
                None,
            ));
        }
    }

    // This sorts the entries for us based on the CSL style.
    Ok(driver.finish(BibliographyRequest {
        style: &style,
        locale: locale_code,
        locale_files: &locales,
    }))
}

#[wasm_func]
pub fn sorted_bib_keys(
    bib: &[u8],
    formats: &[u8],
    full: &[u8],
    style: &[u8],
    style_format: &[u8],
    lang: &[u8],
    cited: &[u8],
) -> Result<Vec<u8>> {
    let sources = str::from_utf8(bib)?.split("%%%").collect::<Vec<_>>();
    let cited = str::from_utf8(cited)?.split(',').collect::<Vec<_>>();
    let formats = str::from_utf8(formats)?.split(',').collect::<Vec<_>>();

    let rendered_bib = generate_bibliography(
        &sources,
        &formats,
        str::from_utf8(full)?.parse()?,
        str::from_utf8(style)?,
        str::from_utf8(style_format)?,
        str::from_utf8(lang)?,
        &cited,
    )?;

    // Gather all correctly sorted references and return their keys!
    let Some(bibliography) = rendered_bib.bibliography else {
        bail!("invalid bibliography");
    };

    let keys = bibliography
        .items
        .iter()
        .map(|i| i.key.clone())
        .collect::<Vec<_>>();

    Ok(keys.join(" ").as_bytes().to_vec())
}
