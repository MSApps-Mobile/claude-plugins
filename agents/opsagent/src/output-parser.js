/**
 * Output Parser — transforms raw agent markdown output into structured OutputSection[] format
 * that the Next.js dashboard can render via the OutputViewer component.
 *
 * Each agent type produces different markdown patterns. This parser extracts:
 * - Summary: key takeaways / what was done
 * - Results: data tables, metrics, outcomes
 * - Attention: warnings, flags, action items
 * - Documents: generated files (proposals, invoices, reports)
 * - Contacts: people mentioned with suggested actions
 */

/**
 * Parse raw agent markdown into OutputSection[] for the dashboard.
 * @param {string} markdown - Raw agent output (after stripping log header)
 * @param {string} agentName - Agent type for context-specific parsing
 * @returns {import('../dashboard/src/lib/types').OutputSection[]}
 */
export function parseAgentOutput(markdown, agentName) {
  if (!markdown || typeof markdown !== 'string') return [];

  // Strip log header if present
  const content = markdown.replace(/^#\s+.+\n\n>.*\n\n---\n\n/, '');

  const sections = [];

  // 1. Extract summary section
  const summary = extractSummary(content, agentName);
  if (summary.items.length > 0) sections.push(summary);

  // 2. Extract results (tables, metrics, data)
  const results = extractResults(content, agentName);
  if (results.items.length > 0) sections.push(results);

  // 3. Extract attention items (warnings, flags, risks)
  const attention = extractAttention(content, agentName);
  if (attention.items.length > 0) sections.push(attention);

  // 4. Extract documents (files generated or referenced)
  const documents = extractDocuments(content, agentName);
  if (documents.items.length > 0) sections.push(documents);

  // 5. Extract contacts (people mentioned)
  const contacts = extractContacts(content, agentName);
  if (contacts.items.length > 0) sections.push(contacts);

  return sections;
}

/**
 * Extract summary / "what was done" from agent output.
 */
function extractSummary(content, agentName) {
  const items = [];

  // Look for common summary patterns
  const summaryPatterns = [
    /##\s*(?:🔥|📋|✅)?\s*(?:Hot Actions|Summary|What Was Done|Overview|Briefing|Report).*?\n([\s\S]*?)(?=\n##\s|\n---|\Z)/gi,
    /##\s*(?:💡)?\s*(?:Recommendation|Next Step|Action Items?).*?\n([\s\S]*?)(?=\n##\s|\n---|\Z)/gi,
  ];

  for (const pattern of summaryPatterns) {
    let match;
    while ((match = pattern.exec(content)) !== null) {
      const block = match[1].trim();
      const bullets = extractBullets(block);
      if (bullets.length > 0) {
        for (const bullet of bullets) {
          items.push({
            icon: 'check',
            text: bullet.text,
            subtitle: bullet.subtitle || undefined,
            actions: bullet.isActionable
              ? [{ label: 'Do it', style: 'primary', icon: 'send' }]
              : undefined,
          });
        }
      } else if (block.length > 10) {
        // Single paragraph summary
        const clean = cleanMarkdown(block);
        items.push({
          icon: 'info',
          text: clean.slice(0, 200) + (clean.length > 200 ? '...' : ''),
        });
      }
    }
  }

  // If no structured summary found, take the first meaningful paragraph
  if (items.length === 0) {
    const firstParagraph = content
      .split('\n\n')
      .find(p => p.length > 30 && !p.startsWith('#') && !p.startsWith('|') && !p.startsWith('>'));
    if (firstParagraph) {
      items.push({
        icon: 'info',
        text: cleanMarkdown(firstParagraph).slice(0, 200),
      });
    }
  }

  return { type: 'summary', title: 'What Was Done', items };
}

/**
 * Extract results — tables, metrics, KPIs from agent output.
 */
function extractResults(content, agentName) {
  const items = [];

  // Extract markdown tables
  const tableRegex = /\|(.+)\|\n\|[-| :]+\|\n((?:\|.+\|\n?)+)/g;
  let match;
  while ((match = tableRegex.exec(content)) !== null) {
    const headers = match[1].split('|').map(h => h.trim()).filter(Boolean);
    const rows = match[2].trim().split('\n');

    for (const row of rows.slice(0, 10)) { // max 10 rows
      const cells = row.split('|').map(c => c.trim()).filter(Boolean);
      if (cells.length >= 2 && !cells[0].startsWith('---')) {
        const text = cells[0].replace(/\*\*/g, '');
        const value = cells.slice(1).join(' · ').replace(/\*\*/g, '');

        // Skip placeholder rows
        if (value.includes('⏳') || value.includes('Needs')) continue;

        items.push({
          icon: 'bar-chart',
          text,
          subtitle: value,
          tag: extractTag(value),
          tagColor: extractTagColor(value),
        });
      }
    }
  }

  // Extract numbered metrics (e.g., "1. Leads Processed: 47")
  const metricRegex = /(?:^|\n)\d+\.\s+\*?\*?(.+?)\*?\*?:\s*(.+)/g;
  while ((match = metricRegex.exec(content)) !== null) {
    items.push({
      icon: 'trending-up',
      text: match[1].trim(),
      subtitle: match[2].trim(),
    });
  }

  return { type: 'results', title: 'Key Results', items };
}

/**
 * Extract attention items — warnings, risks, flags.
 */
function extractAttention(content, agentName) {
  const items = [];

  // Look for warning/risk sections
  const attentionPatterns = [
    /##\s*(?:⚠️|🚨)?\s*(?:Risks?|Flags?|Warnings?|Issues?|Blockers?|Attention|Problems?).*?\n([\s\S]*?)(?=\n##\s|\n---|\Z)/gi,
    /##\s*(?:⚠️)?\s*(?:Structural Risks).*?\n([\s\S]*?)(?=\n##\s|\n---|\Z)/gi,
  ];

  for (const pattern of attentionPatterns) {
    let match;
    while ((match = pattern.exec(content)) !== null) {
      const block = match[1].trim();
      const bullets = extractBullets(block);
      for (const bullet of bullets) {
        items.push({
          icon: 'alert-triangle',
          text: bullet.text,
          subtitle: bullet.subtitle || undefined,
          highlight: true,
          actions: [
            { label: 'Acknowledge', style: 'secondary', icon: 'x' },
          ],
        });
      }

      // Also catch numbered items in risk sections
      const numbered = block.match(/\d+\.\s+\*?\*?(.+?)(?:\n|$)/g);
      if (numbered && bullets.length === 0) {
        for (const item of numbered) {
          const text = cleanMarkdown(item.replace(/^\d+\.\s+/, '').trim());
          if (text.length > 10) {
            items.push({
              icon: 'alert-triangle',
              text: text.slice(0, 200),
              highlight: true,
            });
          }
        }
      }
    }
  }

  // Also catch inline warnings (⚠️ or > ⚠️ blocks)
  const inlineWarnings = content.match(/(?:^|\n)>\s*⚠️\s*(.+?)(?:\n|$)/g);
  if (inlineWarnings) {
    for (const w of inlineWarnings) {
      const text = cleanMarkdown(w.replace(/^>\s*⚠️\s*/, '').trim());
      if (text.length > 10 && !items.some(i => i.text.includes(text.slice(0, 30)))) {
        items.push({
          icon: 'alert-triangle',
          text,
          highlight: true,
        });
      }
    }
  }

  // Deduplicate attention items
  const seen = new Set();
  const deduped = items.filter(item => {
    const key = item.text.slice(0, 60);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  return { type: 'attention', title: 'Needs Attention', items: deduped };
}

/**
 * Extract documents — files generated or referenced in the output.
 */
function extractDocuments(content, agentName) {
  const items = [];

  // Match file references: [name](url) or filename.ext
  const fileRegex = /\[([^\]]+)\]\((https?:\/\/[^\)]+)\)/g;
  let match;
  while ((match = fileRegex.exec(content)) !== null) {
    const name = match[1];
    const url = match[2];

    // Determine file type
    const ext = getFileExtension(name, url);
    if (['pdf', 'docx', 'doc', 'xlsx', 'csv', 'pptx', 'zip'].includes(ext)) {
      items.push({
        icon: 'file',
        text: name,
        subtitle: url,
        tag: ext.toUpperCase(),
        tagColor: ext === 'pdf' ? 'red' : ext.startsWith('doc') ? 'blue' : 'green',
        actions: [
          { label: 'View', style: 'primary', icon: 'eye' },
          { label: 'Download', style: 'secondary', icon: 'download' },
        ],
      });
    }
  }

  // Match Google Drive links
  const driveRegex = /\[([^\]]+)\]\((https:\/\/(?:docs|drive)\.google\.com[^\)]+)\)/g;
  while ((match = driveRegex.exec(content)) !== null) {
    items.push({
      icon: 'file',
      text: match[1],
      subtitle: 'Google Drive',
      tag: 'DRIVE',
      tagColor: 'blue',
      actions: [
        { label: 'Open', style: 'primary', icon: 'eye' },
      ],
    });
  }

  // Agent-specific document patterns
  if (agentName === 'invoicing') {
    const invoiceRegex = /(?:invoice|חשבונית)\s*(?:#?\s*\d+)?.*?(?:₪|NIS|ILS)\s*([\d,]+)/gi;
    while ((match = invoiceRegex.exec(content)) !== null) {
      items.push({
        icon: 'file-text',
        text: `Invoice — ₪${match[1]}`,
        tag: 'PDF',
        tagColor: 'green',
        actions: [
          { label: 'View', style: 'primary', icon: 'eye' },
          { label: 'Send', style: 'success', icon: 'send' },
        ],
      });
    }
  }

  if (agentName === 'social-posts') {
    const postRegex = /(?:(?:LinkedIn|Instagram|Facebook|Twitter|X)\s+(?:post|draft))/gi;
    let postCount = 0;
    while (postRegex.exec(content) !== null) postCount++;
    if (postCount > 0) {
      items.push({
        icon: 'file-text',
        text: `${postCount} social post draft${postCount > 1 ? 's' : ''} created`,
        tag: 'DRAFT',
        tagColor: 'purple',
        actions: [
          { label: 'Review', style: 'primary', icon: 'eye' },
          { label: 'Publish', style: 'success', icon: 'send' },
        ],
      });
    }
  }

  return { type: 'documents', title: 'Documents', items };
}

/**
 * Extract contacts — people mentioned with potential actions.
 */
function extractContacts(content, agentName) {
  const items = [];
  const seen = new Set();

  // Match email addresses
  const emailRegex = /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/g;
  let match;
  while ((match = emailRegex.exec(content)) !== null) {
    const email = match[1];
    if (seen.has(email) || email.includes('example.com') || email.includes('opsagent')) continue;
    seen.add(email);

    // Try to find a name near the email
    const context = content.slice(Math.max(0, match.index - 80), match.index + email.length + 80);
    const nameMatch = context.match(/(?:\*\*|^|\s)([A-Z][a-z]+(?:\s[A-Z][a-z]+)+)/);
    const name = nameMatch ? nameMatch[1] : email.split('@')[0];

    items.push({
      icon: 'user',
      text: name,
      subtitle: email,
      actions: [
        { label: 'Email', style: 'primary', icon: 'send' },
        { label: 'View Profile', style: 'secondary', icon: 'user-plus' },
      ],
    });
  }

  // Match LinkedIn profile URLs
  const linkedinRegex = /(?:linkedin\.com\/in\/([a-zA-Z0-9-]+))/g;
  while ((match = linkedinRegex.exec(content)) !== null) {
    const handle = match[1];
    if (seen.has(handle)) continue;
    seen.add(handle);

    items.push({
      icon: 'user',
      text: handle.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' '),
      subtitle: `linkedin.com/in/${handle}`,
      actions: [
        { label: 'View Profile', style: 'primary', icon: 'eye' },
        { label: 'Add to Segment', style: 'secondary', icon: 'user-plus' },
      ],
    });
  }

  return { type: 'contacts', title: 'Contacts', items };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function extractBullets(block) {
  const bullets = [];
  const lines = block.split('\n');

  for (const line of lines) {
    const bulletMatch = line.match(/^[-*]\s+\*?\*?(.+)/);
    if (bulletMatch) {
      const raw = bulletMatch[1].trim();
      const parts = raw.split(/[—–:]\s*/);
      const text = cleanMarkdown(parts[0]);
      const subtitle = parts.length > 1 ? cleanMarkdown(parts.slice(1).join(' — ')) : null;
      const isActionable = /follow.up|reach out|send|call|schedule|contact|review|check/i.test(raw);

      if (text.length > 5) {
        bullets.push({ text, subtitle, isActionable });
      }
    }
  }

  return bullets;
}

function cleanMarkdown(text) {
  return text
    .replace(/\*\*/g, '')
    .replace(/\*/g, '')
    .replace(/`/g, '')
    .replace(/\[([^\]]+)\]\([^\)]+\)/g, '$1')
    .replace(/^#+\s*/, '')
    .trim();
}

function extractTag(value) {
  const match = value.match(/(₪[\d,]+K?|[\d.]+%|\d+\s*(?:min|hrs?|days?))/i);
  return match ? match[1] : null;
}

function extractTagColor(value) {
  if (/₪|NIS|ILS|\$/.test(value)) return 'green';
  if (/%/.test(value)) return 'blue';
  if (/min|hrs?|days?/i.test(value)) return 'purple';
  return undefined;
}

function getFileExtension(name, url) {
  const fromName = name.match(/\.(\w{2,4})$/)?.[1];
  if (fromName) return fromName.toLowerCase();
  const fromUrl = url.match(/\.(\w{2,4})(?:\?|$)/)?.[1];
  if (fromUrl) return fromUrl.toLowerCase();
  return '';
}

/**
 * Build an ExecutionLog entry from a raw log file.
 * @param {string} clientId
 * @param {string} agentName
 * @param {string} date - YYYY-MM-DD
 * @param {string} content - raw log file content
 */
export function buildExecutionLog(clientId, agentName, date, content) {
  if (!content) return null;

  // Parse header
  const tsMatch = content.match(/^# .+ — .+ — (.+)$/m);
  const tokensMatch = content.match(/Tokens: (\d+) in \/ (\d+) out/);
  const timestamp = tsMatch?.[1] ?? `${date}T00:00:00Z`;

  // Strip header to get agent output
  const output = content.replace(/^#.+\n\n>.*\n\n---\n\n/, '');

  // Parse into structured sections
  const sections = parseAgentOutput(output, agentName);

  // Build summary from first summary section
  const summarySection = sections.find(s => s.type === 'summary');
  const summary = summarySection?.items[0]?.text || `${agentName} completed`;

  // Collect details from attention items
  const details = sections
    .filter(s => s.type === 'attention' || s.type === 'results')
    .flatMap(s => s.items.map(i => i.text))
    .slice(0, 5);

  const agentDepartment = {
    'lead-pipeline': 'Sales',
    'linkedin-outreach': 'Sales',
    'social-posts': 'Marketing',
    'receipts': 'Finance',
    'invoicing': 'Finance',
    'recruiter': 'HR',
  };

  return {
    id: `${clientId}-${agentName}-${date}`,
    agentId: agentName,
    agentName: agentName.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' '),
    department: agentDepartment[agentName] || 'Operations',
    startedAt: timestamp,
    completedAt: timestamp,
    status: 'success',
    summary,
    details,
    outputCount: sections.reduce((n, s) => n + s.items.length, 0),
    output: sections,
  };
}
