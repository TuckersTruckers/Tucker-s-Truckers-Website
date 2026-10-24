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

## 3. Carrier-branded dashboard / customization vision
- [ ] Add carrier company logo upload and display it throughout the carrier-facing portal/dashboard.
- [ ] Design a customizable appearance interface with light mode, dark mode, selectable accent colors, and carrier-defined company colors.
- [ ] Explore AI-assisted logo analysis to suggest a coordinated dashboard theme (palette, contrast-safe text colors, and complementary UI accents); let the carrier preview and approve suggestions before applying them.
- [ ] Make the carrier feel ownership of their own business and workspace, while Tucker’s Truckers quietly handles the operational/technical work behind the scenes.
- [ ] Use co-branding rather than removing Tucker’s Truckers branding entirely: present the experience as “Tucker’s Truckers × [Carrier Name]” (for example, “Tucker’s Truckers × ABC Carrier”), with the carrier’s logo and colors prominent and Tucker’s Truckers retained as the dispatch/operations partner.
- [ ] Define branding hierarchy and placement for the login screen, dashboard header, navigation, emails, documents, and mobile layouts so the experience feels cohesive without confusing who provides the service.
- [ ] Store each carrier’s logo and theme settings securely per carrier account/tenant; verify tenant isolation so one carrier cannot view or change another carrier’s branding assets or settings.
- [ ] Provide sensible defaults and accessible contrast checks so custom colors remain readable in both light and dark modes; include a reset-to-default option.
- [ ] Test logo file type/size validation, upload errors, responsive logo sizing, and fallback behavior when no logo is provided.

**Product principle:** The carrier should feel like they are running their own company—not using a generic Tucker’s Truckers-branded tool. Tucker’s Truckers remains visible as the trusted partner, but the carrier’s identity leads the day-to-day experience.

## 4. Portal follow-up / verification
- [ ] Confirm the updated Carrier setup form saves and reloads every FMCSA and personal-contact field correctly.
- [x] Correct workspace progress indicators to count the three currently available setup areas accurately; clearly label driver management as a later step.
- [ ] Verify the “same as FMCSA” checkboxes copy the intended values and that unchecked fields remain editable.
- [x] Make the workspace fail closed when a login has no assigned role instead of silently treating the account as a carrier; display an access-setup notice.
- [ ] Finish testing carrier role assignment and tenant-level database security before uploading real carrier documents.
- [ ] Review portal grammar and spelling after the public-site editorial pass.

## 5. Admin-managed carrier and driver onboarding
- [x] Add an administrator page for creating carrier and driver accounts, assigning drivers to a carrier, and generating one-time setup links (code committed; deployment and testing remain pending).
- [x] Add a carrier directory and a choice between self-service and admin-assisted profile setup.
- [x] Add a private login-identifier table and Edge Function code for username, phone, and MC-number sign-in (not live until deployed and tested).
- [ ] Run `portal/admin-provisioning-migration.sql` in the correct Supabase project.
- [ ] Audit existing `storage.objects` policies, then run `portal/storage-policies.sql` for the private `carrier-documents` bucket. Confirm no broad/public policy overrides the carrier-folder restrictions.
- [ ] Deploy `admin-provision-account` and `identifier-sign-in` Edge Functions and verify secrets/redirect allow-list.
- [ ] Test self-service and admin-assisted carrier creation with a separate test account; validate setup links and duplicate identifiers.
- [ ] Test creating multiple drivers under separate carriers and verify carrier/driver tenant isolation using RLS and storage policies.
- [ ] Add an administrator workflow for uploading/associating carrier documents and show document-completion state before calling onboarding complete.
- [ ] Add auditable agreement delivery/signing only after the agreement and signing workflow are finalized.

**Important:** Do not create real carrier/driver accounts through the new page until the Supabase migration, Edge Functions, and tenant-security tests are complete. The GitHub commits alone do not deploy database changes or Edge Functions.

---
Last updated: 2026-10-23
