import {
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
});
