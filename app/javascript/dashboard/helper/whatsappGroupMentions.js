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
