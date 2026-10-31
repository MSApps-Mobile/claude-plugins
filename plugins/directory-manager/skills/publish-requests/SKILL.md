---
name: publish-requests
description: >
  Records a publish request on every Claude directory plugin whose newest version passed its checks
  but has no request yet, by clicking "Publish update" in the developer portal. Use when the user says
  "request publish", "publish the passing versions", "push the updates live", "click publish on the
  plugins", or after directory-status lists plugins that need a publish request.
---

# Publish requests (outward action: ask first)

A publish request goes to an Anthropic reviewer, so it is an outward action. **List the plugins you
will click and get the user's yes in chat before clicking.** A yes covers that list only.

## Steps

1. Run `directory-status` (or reuse its result from this session) and take the plugins reported as
   "Needs a publish request".
2. Show the list and ask for a yes.
3. For each plugin, one at a time: open its page, click the **Publish update** button
   (role button, exact name). If a dialog opens, read its text and confirm only a publish or request
   button. Never click Delist, Withdraw, Remove or Rotate.
4. Verify: reload the page and check the status line now says the publish request is waiting for an
   Anthropic reviewer, and that the Publish update button is gone. A click is not proof.
5. Report each plugin as requested, already requested, or failed (with the page's own text).

Reviewers decide; this skill cannot make a version live. Requests seen waiting 7+ days can be raised
with **Contact Anthropic** on the plugin's page or directory@anthropic.com.
