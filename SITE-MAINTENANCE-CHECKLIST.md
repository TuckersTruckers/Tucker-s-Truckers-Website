# Tucker's Truckers — Website Maintenance Checklist

This is the running list of lower-priority cleanup and follow-up tasks. Add new items here as they come up, and mark them complete when verified.

## 1. Website grammar, spelling, and editorial consistency
- [x] Standardize capitalization and heading punctuation across the main public pages and portal pages.
- [x] Update prominent headlines to use consistent Title Case and avoid a trailing period.
- [ ] Proofread all paragraph copy, buttons, form labels, helper text, notices, and metadata for spelling, grammar, clarity, and consistent terminology.
- [ ] Audit form labels against standard carrier/transportation-industry wording; use the specific carrier being onboarded as the subject (for example, “Business / Carrier Name,” not “Primary Business Name”).
- [ ] Review capitalization rules for acronyms and industry terms (FMCSA, USDOT, TONU, dispatching, carrier management) and keep them consistent.
- [ ] Visually review every page after deployment to ensure longer Title Case headings still wrap cleanly on mobile and desktop.

**Editorial convention to follow**
- Headings and short section titles: Title Case, with no final period.
- Body paragraphs and explanatory sentences: normal sentence case with standard punctuation.
- Buttons and short action labels: concise, consistent action wording; no final period.
- Keep the brand voice professional, clear, carrier-first, and practical.

## 2. Investigate DNS / email authentication warning
- [ ] Revisit the failed TXT/DNS authentication check seen in Gmail's “Show original” for a test email.
- [ ] Inspect the exact authentication results before changing DNS. Determine whether the failed check was SPF, DKIM, DMARC, or DNSSEC; these are different checks, and DNSSEC should not be assumed from memory.
- [ ] Verify the current DNS records at the authoritative DNS provider and confirm the actual sending path (Google Workspace / Supabase SMTP).
- [ ] Make only the record changes supported by the actual error, then send a new test email and re-check “Show original.”

**Important:** Do not change or delete DNS/TXT records based only on a remembered warning. Capture the exact “Show original” authentication result first.

## 3. Portal follow-up / verification
- [ ] Confirm the updated Carrier setup form saves and reloads every FMCSA and personal-contact field correctly.
- [ ] Verify the “same as FMCSA” checkboxes copy the intended values and that unchecked fields remain editable.
- [ ] Finish testing carrier role assignment and tenant-level database security before uploading real carrier documents.
- [ ] Review portal grammar and spelling after the public-site editorial pass.

---
Last updated: 2026-10-23
