import {
  decorateWhatsappMentions,
  findWhatsappMentionRanges,
  isWhatsappGroupConversation,
  normalizeWhatsappMentionsForContent,
  renderWhatsappMentions,
} from 'dashboard/helper/whatsappGroupMentions';

describe('#whatsappGroupMentions', () => {
  describe('#isWhatsappGroupConversation', () => {
    it('detects API inbox group conversations from contact inbox source id', () => {
      expect(
        isWhatsappGroupConversation(
          { contact_inbox: { source_id: '120363123@g.us' } },
          true
        )
      ).toBe(true);
    });

    it('detects a group identifier when the contact inbox uses an internal source id', () => {
      expect(
        isWhatsappGroupConversation(
          {
            contact_inbox: {
              source_id: '30cb2246-fae8-4502-9e4c-1595d98005c0',
            },
            meta: {
              sender: { identifier: '120363428151810316@g.us' },
            },
          },
          true
        )
      ).toBe(true);
    });

    it('ignores API inbox conversations without a group identifier', () => {
      expect(
        isWhatsappGroupConversation(
          {
            contact_inbox: {
              source_id: '30cb2246-fae8-4502-9e4c-1595d98005c0',
            },
            meta: {
              sender: { identifier: '5521985294475@s.whatsapp.net' },
            },
          },
          true
        )
      ).toBe(false);
    });

    it('ignores non API inbox conversations', () => {
      expect(
        isWhatsappGroupConversation(
          { contact_inbox: { source_id: '120363123@g.us' } },
          false
        )
      ).toBe(false);
    });
  });

  describe('#normalizeWhatsappMentionsForContent', () => {
    it('keeps selected mentions that are still visible in content', () => {
      const mentions = [
        {
          jid: '5521985294475@s.whatsapp.net',
          lid: '117184105812212@lid',
          phone: '5521985294475',
          label: 'Joao Pedro',
        },
        { jid: '5521999999999@s.whatsapp.net', label: 'Ana Silva' },
        {
          jid: '5521985294475@s.whatsapp.net',
          lid: '117184105812212@lid',
          phone: '5521985294475',
          label: 'Joao Pedro',
        },
      ];

      expect(
        normalizeWhatsappMentionsForContent(
          mentions,
          'Ola @Joao Pedro, pode validar?'
        )
      ).toEqual([
        {
          jid: '5521985294475@s.whatsapp.net',
          lid: '117184105812212@lid',
          phone: '5521985294475',
          label: 'Joao Pedro',
        },
      ]);
    });

    it('keeps selected mentions matched by phone or lid tokens', () => {
      const mentions = [
        {
          jid: '5521985294475@s.whatsapp.net',
          lid: '117184105812212@lid',
          phone: '5521985294475',
          label: 'Joao Pedro',
        },
        {
          jid: '5521981618351@s.whatsapp.net',
          lid: '76716890431647@lid',
          phone: '5521981618351',
          label: 'Stephani',
        },
      ];

      expect(
        normalizeWhatsappMentionsForContent(
          mentions,
          'Ola @117184105812212 e @5521981618351'
        )
      ).toEqual(mentions);
    });
  });

  describe('#renderWhatsappMentions', () => {
    it('renders raw lid mention tokens with the saved mention label', () => {
      expect(
        renderWhatsappMentions('@76716890431647 Quarta', {
          whatsappMentions: [
            {
              jid: '5521987121920@s.whatsapp.net',
              lid: '76716890431647@lid',
              label: 'Flavio Oliveira',
            },
          ],
        })
      ).toBe('@Flavio Oliveira Quarta');
    });

    it('keeps content unchanged when no matching mention exists', () => {
      expect(
        renderWhatsappMentions('@76716890431647 Quarta', {
          whatsappMentions: [
            { jid: '5521987121920@s.whatsapp.net', label: 'Ana' },
          ],
        })
      ).toBe('@76716890431647 Quarta');
    });
  });

  describe('#findWhatsappMentionRanges', () => {
    it('finds only complete mentions selected from the participant list', () => {
      const mentions = [
        {
          lid: '76716890431647@lid',
          label: 'Flavio Oliveira',
        },
      ];

      expect(
        findWhatsappMentionRanges(
          'Oi @Flavio Oliveira, fale com @Flavio OliveiraJunior',
          mentions
        )
      ).toEqual([{ from: 3, to: 19 }]);
    });
  });

  describe('#decorateWhatsappMentions', () => {
    it('decorates a saved label mention for message rendering', () => {
      expect(
        decorateWhatsappMentions('@Flavio Oliveira pode verificar?', {
          whatsapp_mentions: [
            {
              lid: '76716890431647@lid',
              label: 'Flavio Oliveira',
            },
          ],
        })
      ).toBe(
        '[@Flavio Oliveira](mention://whatsapp/76716890431647/Flavio%20Oliveira) pode verificar?'
      );
    });

    it('converts and decorates a raw lid mention token', () => {
      expect(
        decorateWhatsappMentions('@76716890431647 pode verificar?', {
          whatsappMentions: [
            {
              lid: '76716890431647@lid',
              label: 'Flavio Oliveira',
            },
          ],
        })
      ).toBe(
        '[@Flavio Oliveira](mention://whatsapp/76716890431647/Flavio%20Oliveira) pode verificar?'
      );
    });
  });
});
