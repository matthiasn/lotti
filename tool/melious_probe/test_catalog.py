"""The catalog's own claims, checked against itself.

If a model is advertised with `type: chat` and `capabilities.streaming`, the
app is entitled to install it and call it. These tests pin that contract so a
future catalog change that breaks the assumption is visible.
"""

from __future__ import annotations

from typing import Any

import pytest

pytestmark = pytest.mark.live


def test_catalog_is_non_empty(catalog: list[dict[str, Any]]) -> None:
    assert catalog, "The Melious catalog returned no models"
    assert all("id" in entry for entry in catalog), (
        "Every catalog row must carry an id — the app keys models by it"
    )


def test_catalog_exposes_capability_metadata(
    catalog: list[dict[str, Any]],
) -> None:
    """`include_meta=true` must actually include meta.

    The app degrades to a plain `/models` fetch when this fails, losing the
    capability mapping, so a silent regression here is worth catching.
    """
    with_meta = [entry for entry in catalog if entry.get("_meta")]
    assert len(with_meta) > len(catalog) / 2, (
        f"Only {len(with_meta)} of {len(catalog)} rows carried _meta; the "
        "include_meta contract looks broken"
    )


def test_failing_models_are_not_distinguishable_by_metadata(
    catalog: list[dict[str, Any]],
) -> None:
    """The heart of the diagnosis, asserted rather than asserted-by-hand.

    The models that reject a minimal body declare exactly the same
    capabilities as ones that accept it. There is therefore nothing the app
    could read from the catalog to know to treat them differently — which is
    why this cannot be fixed in the request builder.
    """
    rows = {entry["id"]: entry.get("_meta", {}) for entry in catalog}
    broken = "qwen3.8-27b"
    working = "qwen3.6-27b"
    for model in (broken, working):
        if model not in rows:
            pytest.skip(f"{model} is no longer in the catalog")

    def contract(meta: dict[str, Any]) -> dict[str, Any]:
        capabilities = meta.get("capabilities", {})
        return {
            "type": meta.get("type"),
            "input_modalities": meta.get("input_modalities"),
            "output_modalities": meta.get("output_modalities"),
            "streaming": capabilities.get("streaming"),
            "function_calling": capabilities.get("function_calling"),
            "structured_output": capabilities.get("structured_output"),
        }

    assert contract(rows[broken]) == contract(rows[working]), (
        "The broken and working models now differ in advertised capability — "
        "if that is real, the app could route around it after all"
    )
