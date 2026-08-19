# ADR 0008: Keep the 112 handoff simulation-only

## Status

Accepted for Module 8.

## Context

SnakeCare can organize patient-entered emergency information, but it has no approved technical or legal integration with India's Emergency Response Support System (ERSS). Automatic calling or an autonomous voice agent could delay care, misstate a patient's condition, disclose health data without valid consent, or interfere with emergency operations.

## Decision

Module 8 implements a local handoff simulation plus a human-controlled `tel:112` dialler action. It records explicit disclosure consent and minimal audit events. An optional Gemini adapter may classify a temporary microphone transcript into an allow-listed operator-question intent. Gemini cannot generate the medical answer or invoke a tool; the source-bound deterministic engine answers from the consented snapshot. It never contacts ERSS, never infers unconsciousness from silence, never records a real call, and never improvises unknown medical facts.

Any future production integration must be implemented behind a new reviewed adapter after written ERSS approval, legal/privacy/security assessment, safety validation, and a controlled pilot.

## Consequences

The prototype can demonstrate the product idea safely and test its data contract. It cannot claim automatic emergency dispatch or real operator communication. Users must call 112 themselves and must not wait for SnakeCare.
