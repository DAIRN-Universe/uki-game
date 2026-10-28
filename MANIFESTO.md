# DAIRN Technology Manifesto

## Core formulation

**Content defines the world.**

**Rules define what is possible.**

**AI explores the possibilities.**

**Human decides what becomes the story.**

DAIRN is built around distinct sources of meaning and authority. The separation is a technological principle, not a prescription for one framework, transport, model, or deployment topology.

## Content, rules, state, AI, and human choice

- Authored `.dairn` content defines the world, its material, and its intended context. It must not depend on a particular AI model or provider.
- Rules define legal possibilities. Deterministic operations belong in the Engine whenever they can be deterministic; AI is not a source of rules.
- Application and hero state must exist independently of an AI context window or chat history. An AI response cannot become authoritative state merely by being generated.
- AI is useful for probabilistic work: interpretation, generation, recognition, and other tasks for which a deterministic rule is not the right tool. It explores within supplied constraints rather than replacing them.
- AI models and providers are replaceable application components. Their replacement must not rewrite authored content, change rule authority, or erase explicit state.
- Human decision points remain explicit. A person can accept, reject, amend, or defer an AI proposal; the proposal is not the decision.

## DAIRN PRODUCT

**AI proposes.**

**Rules constrain.**

**Human decides.**

This principle applies to the product experience. It preserves a clear distinction between a useful generated suggestion, the rules that bound it, and the human act that makes it part of a story.

## DAIRN DEVELOPMENT

**Human defines.**

**AI implements.**

**Tests verify.**

**Human decides.**

This principle applies to development practice. Humans define intent, boundaries, and acceptance criteria. AI can assist implementation. Tests provide evidence, but final responsibility for accepting a change remains a human decision.

## Scope

This manifesto records principles. It does not claim that every future DAIRN component, storage mechanism, Engine feature, or human interaction has already been implemented in this repository. The concrete Lab boundary and its implemented evidence are recorded in [docs/PRE_EXISTING.md](https://github.com/DAIRN-Universe/dairn-story-teller/blob/main/docs/PRE_EXISTING.md).
