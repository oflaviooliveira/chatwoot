export const isWhatsappGroupConversation = (conversation = {}, isAPIInbox) => {
  if (!isAPIInbox) return false;

  const sourceId =
    conversation?.contact_inbox?.source_id ||
    conversation?.meta?.sender?.identifier ||
    conversation?.meta?.sender?.phone_number ||
    '';

  return sourceId.endsWith('@g.us');
};

export const normalizeWhatsappMentionsForContent = (
  mentions = [],
  content = ''
) => {
  const seen = new Set();

  return mentions
    .filter(mention => {
      const label = mention?.label?.trim();
      return label && content.includes(`@${label}`);
    })
    .filter(mention => {
      if (seen.has(mention.jid)) return false;
      seen.add(mention.jid);
      return true;
    })
    .map(({ jid, label }) => ({ jid, label }));
};

const phoneDigits = value => `${value || ''}`.replace(/\D/g, '');

const mentionLookupKeys = mention => {
  const keys = [];
  const { jid, lid, phone } = mention || {};

  [jid, lid, phone].forEach(value => {
    if (!value) return;
    keys.push(value);
    const digits = phoneDigits(value);
    if (digits) keys.push(digits);
  });

  return keys;
};

const whatsappMentionsFromAttributes = contentAttributes => {
  return (
    contentAttributes?.whatsappMentions ||
    contentAttributes?.whatsapp_mentions ||
    []
  );
};

export const renderWhatsappMentions = (content = '', contentAttributes = {}) => {
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
