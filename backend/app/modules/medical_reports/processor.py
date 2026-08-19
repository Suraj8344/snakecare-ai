from __future__ import annotations

import io
import re
from dataclasses import dataclass

import fitz  # type: ignore[import-untyped]
import pytesseract  # type: ignore[import-untyped]
from PIL import Image

from app.modules.medical_reports.domain import InvalidReportUpload, ReportCategory


@dataclass(frozen=True)
class ProcessingResult:
    text: str
    category: ReportCategory
    summary: str
    engine: str
    confidence: str


class ReportProcessor:
    def __init__(self, max_pdf_pages: int) -> None:
        self.max_pdf_pages = max_pdf_pages

    def process(
        self,
        content: bytes,
        content_type: str,
        filename: str,
        requested_category: ReportCategory | None,
    ) -> ProcessingResult:
        if content_type == "application/pdf":
            text, engine = self._pdf_text(content)
        else:
            text, engine = self._image_text(content)
        normalized = self._normalize(text)
        category = requested_category or self._categorize(filename, normalized)
        return ProcessingResult(
            text=normalized,
            category=category,
            summary=self._summarize(normalized),
            engine=engine,
            confidence="unscored",
        )

    def _pdf_text(self, content: bytes) -> tuple[str, str]:
        try:
            document = fitz.open(stream=content, filetype="pdf")
        except Exception as exc:
            raise InvalidReportUpload from exc
        with document:
            if document.page_count > self.max_pdf_pages:
                raise InvalidReportUpload
            embedded = "\n".join(page.get_text("text") for page in document)
            if len(embedded.strip()) >= 40:
                return embedded, "pymupdf-embedded-text"
            pages: list[str] = []
            for page in document:
                pixmap = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
                image = Image.open(io.BytesIO(pixmap.tobytes("png")))
                pages.append(pytesseract.image_to_string(image))
            return "\n".join(pages), "tesseract-pdf-ocr"

    def _image_text(self, content: bytes) -> tuple[str, str]:
        try:
            image = Image.open(io.BytesIO(content))
            image.verify()
            image = Image.open(io.BytesIO(content))
            return pytesseract.image_to_string(image), "tesseract-image-ocr"
        except Exception as exc:
            raise InvalidReportUpload from exc

    @staticmethod
    def _normalize(text: str) -> str:
        return re.sub(r"[ \t]+", " ", re.sub(r"\r\n?", "\n", text)).strip()[:100_000]

    @staticmethod
    def _categorize(filename: str, text: str) -> ReportCategory:
        haystack = f"{filename} {text}".lower()
        rules = (
            (ReportCategory.LAB_RESULT, ("laboratory", "lab result", "haemoglobin", "hemoglobin")),
            (ReportCategory.PRESCRIPTION, ("prescription", "rx", "dosage")),
            (ReportCategory.IMAGING, ("radiology", "x-ray", "mri", "ct scan", "ultrasound")),
            (ReportCategory.DISCHARGE_SUMMARY, ("discharge summary", "discharged")),
            (ReportCategory.VACCINATION, ("vaccination", "vaccine", "immunization")),
            (ReportCategory.INSURANCE, ("insurance", "policy number", "claim")),
            (ReportCategory.SURGERY, ("surgery", "operative", "procedure")),
        )
        for category, terms in rules:
            if any(term in haystack for term in terms):
                return category
        return ReportCategory.OTHER

    @staticmethod
    def _summarize(text: str) -> str:
        if not text:
            return "No readable text was detected. Review the original report."
        sentences = [item.strip() for item in re.split(r"(?<=[.!?])\s+|\n+", text) if item.strip()]
        selected = " ".join(sentences[:5])[:1_200]
        return selected or "Readable text was detected; review the original report."
