## Context

Both submission links exist as disabled placeholders. The Google Form URL is now available.

## Goals / Non-Goals

**Goals:** Activate both links using URL from golem-config.yml (single source of truth).

**Non-Goals:** Form creation (done by maintainer), submission workflow automation.

## Decisions

**1. Store URL in golem-config.yml** — single source of truth, per spec §6.1.

## Risks / Trade-offs

- [Risk] URL changes → One-line config change + redeploy
