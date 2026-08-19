export const isWhatsappGroupConversation = (conversation, isAPIInbox) => {
  if (!isAPIInbox) return false;

  const sourceIds = [
    conversation?.contact_inbox?.source_id,
    conversation?.meta?.sender?.identifier,
    conversation?.meta?.sender?.phone_number,
  ];

  return sourceIds.some(sourceId => sourceId?.endsWith('@g.us'));
};

const phoneDigits = value => `${value || ''}`.replace(/\D/g, '');

const escapeRegExp = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const mentionLookupKeys = mention => {
  const keys = [];
  const { jid, label, lid, phone, token } = mention || {};

  [label, token, jid, lid, phone].forEach(value => {
    if (!value) return;
    keys.push(`${value}`.trim());
    const digits = phoneDigits(value);
    if (digits) keys.push(digits);
  });

  return [...new Set(keys.filter(Boolean))];
};

const whatsappMentionMatches = (content = '', mentions = []) => {
  if (!content || !mentions.length) return [];

  const mentionsByToken = mentions.reduce((acc, mention) => {
    const label = mention?.label?.trim();
    if (!label) return acc;

    mentionLookupKeys(mention).forEach(key => {
      acc[key] ||= mention;
    });
    return acc;
  }, {});

  const tokens = Object.keys(mentionsByToken).sort(
    (first, second) => second.length - first.length
  );
  if (!tokens.length) return [];

  const matcher = new RegExp(
    `@(${tokens.map(escapeRegExp).join('|')})(?![\\p{L}\\p{N}_])`,
    'gu'
  );

  return [...content.matchAll(matcher)].map(match => ({
    from: match.index,
    to: match.index + match[0].length,
    mention: mentionsByToken[match[1]],
  }));
};

export const normalizeWhatsappMentionsForContent = (
  mentions = [],
  content = ''
) => {
  const seen = new Set();

  return mentions
    .filter(mention => {
      return mentionLookupKeys(mention).some(key =>
        content.includes(`@${key}`)
      );
    })
    .filter(mention => {
      const mentionIdentifier = mention.jid || mention.lid || mention.phone;
      if (!mentionIdentifier || seen.has(mentionIdentifier)) return false;
      seen.add(mentionIdentifier);
      return true;
    })
    .map(({ jid, lid, phone, label }) =>
      Object.fromEntries(
        Object.entries({ jid, lid, phone, label }).filter(([, value]) => value)
      )
    );
};

const whatsappMentionsFromAttributes = contentAttributes => {
  return (
    contentAttributes?.whatsappMentions ||
    contentAttributes?.whatsapp_mentions ||
    []
  );
};

export const renderWhatsappMentions = (
  content = '',
  contentAttributes = {}
) => {
  const mentions = whatsappMentionsFromAttributes(contentAttributes);
  if (!content || !mentions.length) return content;

  const mentionsByToken = mentions.reduce((acc, mention) => {
    const label = mention?.label?.trim();
    if (!label) return acc;

    mentionLookupKeys(mention).forEach(key => {
      acc[key] ||= label;
    });
    return acc;
  }, {});

  if (!Object.keys(mentionsByToken).length) return content;

  return content.replace(/@(\d{6,})(?!\w)/g, (match, token) => {
    const label = mentionsByToken[token];
    return label ? `@${label}` : match;
  });
};

export const findWhatsappMentionRanges = (content = '', mentions = []) => {
  return whatsappMentionMatches(content, mentions).map(({ from, to }) => ({
    from,
    to,
  }));
};

const escapeMarkdownLabel = label => label.replace(/([\\[\]])/g, '\\$1');

export const decorateWhatsappMentions = (
  content = '',
  contentAttributes = {}
) => {
  const mentions = whatsappMentionsFromAttributes(contentAttributes);
  const renderedContent = renderWhatsappMentions(content, contentAttributes);
  const matches = whatsappMentionMatches(renderedContent, mentions);
  if (!matches.length) return renderedContent;

  let decoratedContent = '';
  let cursor = 0;

  matches.forEach(({ from, to, mention }) => {
    const label = mention.label.trim();
    const identifier =
      phoneDigits(
        mention.lid || mention.jid || mention.phone || mention.token
      ) || 'unknown';

    decoratedContent += renderedContent.slice(cursor, from);
    decoratedContent += `[@${escapeMarkdownLabel(label)}](mention://whatsapp/${identifier}/${encodeURIComponent(label)})`;
    cursor = to;
  });

  return decoratedContent + renderedContent.slice(cursor);
};
