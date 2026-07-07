"""
Medical knowledge base loading and semantic retrieval.

Two key design decisions:

  1. CONTENT AND CODE ARE FULLY DECOUPLED.
     Protocol text lives in data/knowledge_base.json (Person C's domain).
     This module only knows how to load and search it. Person C can add,
     remove, or correct protocol entries without ever reading this file.
     The schema is validated here at load time so errors are caught early.

  2. REAL SEMANTIC RETRIEVAL, NOT KEYWORD MATCHING.
     The original hackathon code matched alerts by checking if a word from
     the alert appeared anywhere in a knowledge sentence. That is fragile —
     it matches for accidental reasons as easily as correct ones.

     Here, both the query and every knowledge entry are embedded into the
     same vector space (sentence-transformers). Retrieval finds the closest
     passages by meaning, not by word overlap. "Tachycardia" matches
     "elevated heart rate" even though they share no words. This is
     standard dense retrieval (the R in RAG) — not a toy approximation.

Performance: KnowledgeStore is constructed ONCE at app startup (embedding
the KB is the expensive step). Every call to retrieve() is a fast FAISS
nearest-neighbour search — microseconds, not seconds.
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import numpy as np

from sanjeevani.config import CFG, KB_PATH
from sanjeevani.core.models import KnowledgePassage
from sanjeevani.exceptions import KnowledgeError

log = logging.getLogger("sanjeevani.knowledge.store")

# Required fields in every knowledge base JSON entry
_REQUIRED_FIELDS = {"id", "text", "source_ref"}


@dataclass(frozen=True)
class _Entry:
    """Internal representation of one knowledge base entry."""
    entry_id:   str
    text:       str
    source_ref: str
    tags:       tuple[str, ...]


def _load_and_validate(path: Path) -> list[_Entry]:
    """Load and schema-validate the knowledge base JSON file."""
    if not path.exists():
        raise KnowledgeError(
            f"Knowledge base not found at {path}. "
            "The intelligence layer cannot operate without verified protocol "
            "content. Populate data/knowledge_base.json before starting the "
            "application. See docs/knowledge_base_schema.md for the format."
        )

    try:
        raw: list[dict] = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise KnowledgeError(
            f"knowledge_base.json contains invalid JSON: {exc}"
        ) from exc

    if not isinstance(raw, list) or not raw:
        raise KnowledgeError(
            "knowledge_base.json must contain a non-empty JSON array. "
            f"Got: {type(raw).__name__}"
        )

    entries: list[_Entry] = []
    for i, item in enumerate(raw):
        missing = _REQUIRED_FIELDS - set(item.keys())
        if missing:
            raise KnowledgeError(
                f"Entry #{i} (id={item.get('id', 'UNKNOWN')}) is missing "
                f"required fields: {sorted(missing)}"
            )
        if not item["text"].strip():
            raise KnowledgeError(f"Entry #{i} has an empty 'text' field.")

        entries.append(_Entry(
            entry_id=str(item["id"]),
            text=item["text"].strip(),
            source_ref=str(item["source_ref"]),
            tags=tuple(item.get("tags", [])),
        ))

    log.info("Knowledge base loaded: %d entries from %s", len(entries), path)
    return entries


class KnowledgeStore:
    """
    Semantic retrieval over the medical knowledge base using FAISS.

    Thread-safe for reads after construction. Construct once at startup.
    """

    def __init__(self, kb_path: Optional[Path] = None) -> None:
        from sentence_transformers import SentenceTransformer
        import faiss

        self._faiss  = faiss
        self._entries = _load_and_validate(kb_path or KB_PATH)

        log.info("Loading embedding model: %s", CFG.retrieval.embedding_model)
        self._model = SentenceTransformer(CFG.retrieval.embedding_model)

        # Embed all entries and build the FAISS index
        texts = [e.text for e in self._entries]
        vecs  = self._model.encode(
            texts,
            normalize_embeddings=True,
            batch_size=CFG.retrieval.batch_size,
            show_progress_bar=False,
        )
        vecs = np.asarray(vecs, dtype="float32")
        dim  = vecs.shape[1]

        # IndexFlatIP performs exact inner-product search.
        # With L2-normalized vectors, inner product = cosine similarity.
        self._index = faiss.IndexFlatIP(dim)
        self._index.add(vecs)
        log.info(
            "FAISS index ready: %d vectors, dim=%d", self._index.ntotal, dim
        )

    # ── Public API ────────────────────────────────────────────────────────────

    def retrieve(self, query: str) -> tuple[KnowledgePassage, ...]:
        """
        Find the most relevant protocol passages for a symptom query.

        Performs dense nearest-neighbour retrieval and filters results by
        the minimum similarity threshold in config. Returns an empty tuple
        when no passage clears the threshold — callers must treat this as a
        real signal ('no confident match') and not paper over it.

        Args:
            query: A natural-language description of symptoms or alerts.
                   May be the concatenation of alert strings + transcript.

        Returns:
            A tuple of KnowledgePassage objects (may be empty), ordered by
            descending similarity.
        """
        if not query or not query.strip():
            log.warning("retrieve() called with empty query — returning empty")
            return ()

        q_vec = self._model.encode(
            [query.strip()],
            normalize_embeddings=True,
            show_progress_bar=False,
        )
        q_vec = np.asarray(q_vec, dtype="float32")

        k      = min(CFG.retrieval.top_k, len(self._entries))
        scores, indices = self._index.search(q_vec, k)

        results: list[KnowledgePassage] = []
        for score, idx in zip(scores[0], indices[0]):
            if idx < 0:
                continue
            sim = float(score)
            if sim < CFG.retrieval.min_similarity:
                continue
            e = self._entries[idx]
            results.append(KnowledgePassage(
                entry_id=e.entry_id,
                source_ref=e.source_ref,
                text=e.text,
                similarity=sim,
            ))

        log.info(
            "Retrieval: returned=%d/%d above_threshold=%.2f query_len=%d",
            len(results), k, CFG.retrieval.min_similarity, len(query),
        )
        return tuple(results)
