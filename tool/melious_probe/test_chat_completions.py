"""Does the provider accept a minimal, indisputably valid chat request?

The whole suite exists to answer one question: when Melious replies "the
request was rejected as malformed", is the request actually malformed? Every
test here sends the smallest body the OpenAI chat schema allows, so a rejection
cannot be attributed to an optional parameter we chose to send.
"""

from __future__ import annotations

import json

import pytest

from melious import MeliousClient, Outcome, Probe, minimal_chat_body

# Melious rejects a chat request for these models unless `reasoning_effort` is
# present, and rejects `high`. Measured five times per cell on 2026-08-26.
REASONING_EFFORT_REQUIRED = ("qwen3.8-27b", "qwen3.8-max")

# Models observed to answer a minimal request. Used as the control group: if
# these ever start failing too, the fault is the harness or the account, not
# the individual model.
CONTROL_MODELS = ("glm-5.2", "kimi-k3", "qwen3.6-27b")


def test_minimal_body_is_schema_valid() -> None:
    """Guards the premise of every other test in this file.

    Runs offline. If the body ever grows an optional field, a "malformed"
    verdict stops being evidence about the provider.
    """
    body = minimal_chat_body("some-model")
    assert set(body) == {"model", "messages"}, (
        "The probe body must stay minimal — extra fields would give the "
        f"provider something legitimate to reject. Got: {sorted(body)}"
    )
    assert body["messages"] == [{"role": "user", "content": "Say OK"}]
    json.dumps(body)  # must be serialisable exactly as sent


@pytest.mark.live
@pytest.mark.parametrize("model", CONTROL_MODELS)
def test_control_models_accept_minimal_body(
    client: MeliousClient, recorder: list[Probe], model: str
) -> None:
    """The account and the harness are both healthy."""
    probe = client.probe_chat(model)
    recorder.append(probe)
    assert probe.ok, (
        f"Control model {model} failed with HTTP {probe.status} "
        f"({probe.outcome}): {probe.message}. Either the credential lost "
        "access or the probe itself is wrong — fix that before trusting any "
        "other result in this file."
    )


@pytest.mark.live
def test_only_the_model_id_differs(
    client: MeliousClient, recorder: list[Probe]
) -> None:
    """The decisive experiment.

    Two requests identical but for the model id: one is accepted, one is
    called malformed. Since the bytes are otherwise the same, the payload
    cannot be what is wrong.
    """
    accepted = client.probe_chat("qwen3.6-27b")
    rejected = client.probe_chat("qwen3.8-27b")
    recorder.extend((accepted, rejected))

    accepted_body = minimal_chat_body("qwen3.6-27b")
    rejected_body = minimal_chat_body("qwen3.8-27b")
    difference = {
        key
        for key in accepted_body
        if accepted_body[key] != rejected_body[key]
    }
    assert difference == {"model"}, (
        f"The two bodies must differ only in the model id, got {difference}"
    )

    assert accepted.ok, f"Expected qwen3.6-27b to work: {accepted.message}"
    assert rejected.outcome is Outcome.MALFORMED, (
        "Expected qwen3.8-27b to reject a body with no reasoning_effort, got "
        f"HTTP {rejected.status}: {rejected.message}. If this now passes, the "
        "provider has dropped the requirement and the quirk table in "
        "MeliousInferenceRepository can lose this model."
    )


@pytest.mark.live
def test_catalog_model_accepts_minimal_body(
    client: MeliousClient, recorder: list[Probe], chat_model: str
) -> None:
    """Every model the catalog advertises as chat-capable should answer.

    A 5xx is capacity, not a contract breach, so it is reported and skipped.
    A 400 on this body is a genuine defect: the provider is advertising a
    model it will not serve, and blaming the caller for it.
    """
    probe = client.probe_chat(chat_model)
    recorder.append(probe)

    if probe.outcome is Outcome.UPSTREAM_ERROR:
        pytest.skip(
            f"{chat_model}: transient upstream error after {probe.attempts} "
            f"attempts (HTTP {probe.status})"
        )

    assert probe.ok, (
        f"{chat_model} is advertised as a chat model but returned HTTP "
        f"{probe.status} ({probe.outcome}) for a two-field body: "
        f"{probe.message} [x-request-id: {probe.request_id}]"
    )


@pytest.mark.live
@pytest.mark.parametrize("model", REASONING_EFFORT_REQUIRED)
def test_reasoning_effort_is_what_the_400_is_really_about(
    client: MeliousClient, recorder: list[Probe], model: str
) -> None:
    """Pins the actual contract these models enforce.

    Adding one field turns the rejection into an answer, which is the whole
    basis for the fix in `MeliousInferenceRepository.resolveReasoningEffort`.
    `high` is rejected, so the app clamps to `medium`.
    """
    without = client.probe_chat(model, retries=0)
    body = minimal_chat_body(model) | {"reasoning_effort": "low"}
    with_low = client.probe_chat(model, body=body, retries=0)
    too_high = client.probe_chat(
        model, body=minimal_chat_body(model) | {"reasoning_effort": "high"},
        retries=0,
    )
    recorder.extend((without, with_low, too_high))

    assert without.outcome is Outcome.MALFORMED, (
        f"{model} was expected to reject a body with no reasoning_effort, "
        f"got HTTP {without.status}"
    )
    assert with_low.ok, (
        f"{model} rejected reasoning_effort=low (HTTP {with_low.status}: "
        f"{with_low.message}) — the fix's default is no longer valid"
    )
    assert too_high.outcome is Outcome.MALFORMED, (
        f"{model} now accepts reasoning_effort=high (HTTP {too_high.status}) "
        "— the clamp to medium is no longer needed"
    )
