"""Patch defect_act_template.docx XML with single-run placeholders."""
from __future__ import annotations

import io
import re
import shutil
import zipfile
from pathlib import Path

SRC_DOC = Path(
    r"c:\Users\User\Downloads\С флешки\Aкты\Новгородские АЗС\Дефектация\акт деф.doc"
)
OUT_DOCX = Path(r"d:\azs_bot\mobile\assets\templates\defect_act_template.docx")


def convert_doc_to_docx() -> None:
    import os
    import win32com.client

    OUT_DOCX.parent.mkdir(parents=True, exist_ok=True)
    word = win32com.client.Dispatch("Word.Application")
    word.Visible = False
    try:
        doc = word.Documents.Open(os.path.abspath(str(SRC_DOC)))
        doc.SaveAs2(os.path.abspath(str(OUT_DOCX)), FileFormat=12)
        doc.Close(False)
    finally:
        word.Quit()


def patch_wt(texts: list[str]) -> list[str]:
    out = texts[:]

    out[5] = '"{{ACT_DAY}}" {{ACT_MONTH}}'
    out[6] = ""
    out[7] = "{{ACT_YEAR}}"

    out[13] = "{{ACT_NUMBER}}"
    out[14] = ""

    out[24] = ":{{ASSESSMENT}}"
    out[25] = out[26] = out[27] = ""

    out[38] = " {{STATION_NUMBER}} "
    out[39] = out[40] = out[41] = out[42] = out[43] = out[44] = ""
    out[45] = '"{{STATION_DAY}}" {{STATION_MONTH}}'
    out[46] = out[47] = out[48] = ""
    out[49] = "{{STATION_YEAR}}"

    out[52] = "Адрес объекта:"
    out[53] = ""
    out[54] = ""
    out[55] = "{{STATION_ADDRESS}}"
    out[56] = ""

    out[59] = "{{DECLARED_FAULT}}"
    out[60] = out[61] = out[62] = ""

    out[66] = "{{FAULTY}}"

    out[68] = "{{CONCLUSION}}"
    out[69] = out[70] = out[71] = out[72] = ""

    return out


def patch_document_xml(xml: str) -> str:
    texts = re.findall(r"(<w:t[^>]*>)([^<]*)(</w:t>)", xml)
    if len(texts) < 73:
        raise RuntimeError(f"Unexpected w:t count: {len(texts)}")

    plain = [t[1] for t in texts]
    patched = patch_wt(plain)

    idx = 0

    def repl(match: re.Match[str]) -> str:
        nonlocal idx
        prefix, _, suffix = texts[idx]
        value = patched[idx]
        idx += 1
        return f"{prefix}{value}{suffix}"

    return re.sub(r"(<w:t[^>]*>)([^<]*)(</w:t>)", repl, xml, count=len(texts))


def main() -> None:
    convert_doc_to_docx()

    with zipfile.ZipFile(OUT_DOCX, "r") as zin:
        entries = {name: zin.read(name) for name in zin.namelist()}

    xml = entries["word/document.xml"].decode("utf-8")
    entries["word/document.xml"] = patch_document_xml(xml).encode("utf-8")

    backup = OUT_DOCX.with_suffix(".docx.bak")
    shutil.copy2(OUT_DOCX, backup)

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zout:
        for name, data in entries.items():
            zout.writestr(name, data)
    OUT_DOCX.write_bytes(buf.getvalue())
    print("patched", OUT_DOCX)


if __name__ == "__main__":
    main()
