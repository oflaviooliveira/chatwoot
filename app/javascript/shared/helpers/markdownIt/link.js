// Process [@mention](mention://user/1/Pranav) and WhatsApp group mentions.
const MENTIONS_REGEX = /^mention:\/\/(user|team|whatsapp)\/([^/]+)\/(.+)$/;

const buildMentionTokens = () => (state, silent) => {
  var label;
  var labelEnd;
  var labelStart;
  var pos;
  var res;
  var token;
  var href = '';
  var max = state.posMax;

  if (state.src.charCodeAt(state.pos) !== 0x5b /* [ */) {
    return false;
  }

  labelStart = state.pos + 1;
  labelEnd = state.md.helpers.parseLinkLabel(state, state.pos, true);

  // parser failed to find ']', so it's not a valid link
  if (labelEnd < 0) {
    return false;
  }

  label = state.src.slice(labelStart, labelEnd);
  pos = labelEnd + 1;

  if (pos < max && state.src.charCodeAt(pos) === 0x28 /* ( */) {
    pos += 1;
    res = state.md.helpers.parseLinkDestination(state.src, pos, state.posMax);
    if (res.ok) {
      href = state.md.normalizeLink(res.str);
      if (state.md.validateLink(href)) {
        pos = res.pos;
      } else {
        href = '';
      }
    }
    pos += 1;
  }

  const mentionMatch = href.match(MENTIONS_REGEX);
  if (!mentionMatch) {
    return false;
  }

  if (!silent) {
    state.pos = labelStart;
    state.posMax = labelEnd;

    token = state.push('mention', '');
    token.href = href;
    token.content = label;
    token.mentionType = mentionMatch[1];
  }

  state.pos = pos;
  state.posMax = max;

  return true;
};

const renderMentions = md => (tokens, idx) => {
  const className =
    tokens[idx].mentionType === 'whatsapp'
      ? 'whatsapp-mention-node'
      : 'prosemirror-mention-node';
  const content = md.utils.escapeHtml(tokens[idx].content);

  return `<span class="${className}">${content}</span>`;
};

export default function mentionPlugin(md) {
  md.renderer.rules.mention = renderMentions(md);
  md.inline.ruler.before('link', 'mention', buildMentionTokens(md));
}
