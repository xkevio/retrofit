use core::str;

use hayagriva::{
    archive::{locales, ArchivedStyle},
    citationberg::{IndependentStyle, LocaleCode, Style},
    io::{from_biblatex_str, from_yaml_str},
    BibliographyDriver, BibliographyRequest, CitationItem, CitationRequest, Library, Rendered,
};
use wasm_minimal_protocol::*;

initiate_protocol!();

/// Generates a `Rendered` hayagriva bibliography object (and whether it is sorted) based on the given arguments.
/// - `bib` represents the contents of either a BibTeX file or a hayagriva YAML file.
/// - `full` represents whether to include all works from the given bibliography files.
/// - `style` may either represent the raw text of the given CSL style or its `ArchivedName`.
/// - `style_format` should be `csl | text` to tell the function what to do with `style`.
/// - `lang` represents a RFC 1766 language code.
/// - `cited` should contain all used citations when `full: false` or None when `full: true`.
pub(crate) fn generate_bibliography(
    bib: &[&str],
    full: bool,
    style: &str,
    style_format: &str,
    lang: &str,
    cited: Option<&[&str]>,
) -> Result<Rendered, String> {
    // Merge multiple bibliographies into one, be it BibTeX or YAML format.
    let bib = bib.iter().try_fold(Library::new(), |mut acc, s| {
        if let Ok(library) = from_yaml_str(s).or_else(|_| from_biblatex_str(s)) {
            for entry in library {
                acc.push(&entry);
            }
        } else {
            return Err(String::from("error while reading bibliography!"));
        }

        Ok(acc)
    })?;

    // If `style_format` is "csl", we expect Typst to pass the raw file contents for us,
    // as we cannot read from the filesystem as a WASM application. Otherwise, use `archive`.
    let style = if style_format == "csl" {
        IndependentStyle::from_xml(style).unwrap()
    } else {
        let Style::Independent(indep) = ArchivedStyle::by_name(style).unwrap().get() else {
            return Err("invalid independent style!".to_string());
        };

        indep
    };

    let locales = locales();
    let locale_code = Some(LocaleCode(String::from(lang)));
    let mut driver = BibliographyDriver::new();

    // If sort is none, we manually sort by order of appearance within the Typst document.
    // The parameter `cited` should represent this order, as such we iterate over it.
    if style
        .bibliography
        .as_ref()
        .is_some_and(|b| b.sort.is_none() && !full)
    {
        for key in cited.unwrap() {
            let entry = bib.get(key);
            if let Some(entry) = entry {
                let items = vec![CitationItem::with_entry(entry)];
                driver.citation(CitationRequest::new(
                    items,
                    &style,
                    locale_code.clone(),
                    &locales,
                    None,
                ));
            } else {
                return Err(format!("Cannot find {} in bibliography file", key));
            }
        }
    } else {
        for entry in bib
            .iter()
            .filter(|e| full || cited.unwrap().contains(&e.key()))
        {
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

    Ok(driver.finish(BibliographyRequest {
        style: &style,
        locale: locale_code,
        locale_files: &locales,
    }))
}

#[wasm_func]
pub fn sorted_bib_keys(
    bib: &[u8],
    full: &[u8],
    style: &[u8],
    style_format: &[u8],
    lang: &[u8],
    cited: &[u8],
) -> Result<Vec<u8>, String> {
    let cited_str = str::from_utf8(cited).unwrap();
    let cited = cited_str.split(',').collect::<Vec<_>>();
    let sources = str::from_utf8(bib)
        .unwrap()
        .split("%%%")
        .collect::<Vec<_>>();
    let full = str::from_utf8(full).is_ok_and(|f| f == "true");

    let rendered_bib = generate_bibliography(
        &sources,
        full,
        str::from_utf8(style).unwrap(),
        str::from_utf8(style_format).unwrap(),
        str::from_utf8(lang).unwrap(),
        if full { None } else { Some(&cited) },
    )?;

    // Gather all correctly sorted references and return their keys!
    let Some(bibliography) = rendered_bib.bibliography else {
        return Err("invalid bibliography".to_string());
    };

    let keys = bibliography
        .items
        .iter()
        .map(|i| i.key.clone())
        .collect::<Vec<_>>();

    Ok(keys.join(" ").as_bytes().to_vec())
}
