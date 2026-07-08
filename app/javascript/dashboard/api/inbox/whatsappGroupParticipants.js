/* global axios */
import ApiClient from '../ApiClient';

class WhatsappGroupParticipantsAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  get(conversationId) {
    return axios.get(`${this.url}/${conversationId}/whatsapp_group_participants`);
  }
}

export default new WhatsappGroupParticipantsAPI();
